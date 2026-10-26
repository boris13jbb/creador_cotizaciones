import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:universal_io/io.dart';

import '../models/org_branding.dart';
import '../models/org_client.dart';
import '../models/quote.dart';
import '../services/branding_storage_service.dart';
import '../services/client_repository.dart';
import '../services/cloud_cotizacion_repository.dart';
import '../services/organization_service.dart';
import 'branding_local_cache.dart';
import 'connectivity_monitor.dart';
import 'offline_local_store.dart';
import 'offline_sync_status.dart';

/// Procesa la cola persistente cuando Firebase es alcanzable.
///
/// Limitación Android: sin WorkManager dedicado, la sync en segundo plano
/// solo ocurre con la app en primer plano (o tras un arranque). La cola
/// sí sobrevive a reinicios; al abrir la app se reanuda.
class OfflineSyncService {
  OfflineSyncService._();
  static final OfflineSyncService instance = OfflineSyncService._();

  bool _running = false;

  Future<bool> canReachFirebase() => ConnectivityMonitor.instance.probeFirebase();

  /// Último error de ítem de cola (para UI).
  String? lastItemError;

  Future<int> syncPending({
    required String organizationId,
    required String uid,
  }) async {
    if (_running) return 0;
    final reachable = await canReachFirebase();
    if (!reachable) return 0;

    _running = true;
    var completed = 0;
    lastItemError = null;
    try {
      final queue = await OfflineLocalStore.instance.pendingQueue(
        organizationId: organizationId,
        uid: uid,
      );
      for (final item in queue) {
        try {
          await _processItem(item);
          await OfflineLocalStore.instance.markQueueCompleted(item.id);
          completed++;
        } catch (e, st) {
          debugPrint('offline sync item ${item.id}: $e\n$st');
          lastItemError = e.toString().replaceFirst('Exception: ', '');
          await OfflineLocalStore.instance.markQueueFailed(item.id, '$e');
          if (item.entityType == OfflineEntityType.quote) {
            final isConflict = lastItemError!.contains('Conflicto');
            await OfflineLocalStore.instance.markQuoteStatus(
              organizationId: item.organizationId,
              uid: item.uid,
              quoteId: item.entityId,
              status: isConflict
                  ? OfflineSyncStatus.conflict
                  : OfflineSyncStatus.error,
              conflictPayloadJson: isConflict ? '{"source":"sync_queue"}' : null,
            );
          }
        }
      }
    } finally {
      _running = false;
    }
    return completed;
  }

  Future<void> _processItem(SyncQueueItem item) async {
    switch (item.entityType) {
      case OfflineEntityType.client:
        final client = OrgClient.fromMap(item.payload);
        await ClientRepository.instance.upsert(
          organizationId: item.organizationId,
          client: client,
          skipOfflineMirror: true,
        );
        await OfflineLocalStore.instance.markClientStatus(
          organizationId: item.organizationId,
          uid: item.uid,
          clientId: client.id,
          status: OfflineSyncStatus.synced,
        );
      case OfflineEntityType.quote:
        final quote = Quote.fromMap(item.payload);
        final isNew = item.payload['__isNew'] == true;
        // Evitar sobrescritura silenciosa si el remoto cambió en otro dispositivo.
        if (!isNew) {
          final remote =
              await CloudCotizacionRepository.instance.getQuoteRemoteOnly(
            quote.id,
          );
          if (remote != null &&
              remote.updatedAt.isAfter(quote.updatedAt) &&
              remote.version != quote.version) {
            await OfflineLocalStore.instance.upsertQuote(
              uid: item.uid,
              quote: quote,
              status: OfflineSyncStatus.conflict,
              conflictPayloadJson:
                  '{"remoteUpdatedAt":"${remote.updatedAt.toIso8601String()}",'
                  '"remoteVersion":${remote.version}}',
            );
            throw Exception(
              'Conflicto de sincronización: la cotización cambió en otro dispositivo.',
            );
          }
        }
        try {
          await CloudCotizacionRepository.instance.saveQuoteRemoteOnly(
            quote,
            isNew: isNew,
          );
        } catch (e) {
          // Cupo Free agotado: conservar local, no borrar, marcar error recuperable.
          if (isNew &&
              (e.toString().contains('resource-exhausted') ||
                  e.toString().toLowerCase().contains('límite del plan') ||
                  e.toString().toLowerCase().contains('limite del plan'))) {
            await OfflineLocalStore.instance.upsertQuote(
              uid: item.uid,
              quote: quote,
              status: OfflineSyncStatus.error,
              conflictPayloadJson:
                  '{"code":"resource-exhausted","message":"${e.toString().replaceAll('"', "'")}"}',
            );
          }
          rethrow;
        }
        await OfflineLocalStore.instance.markQuoteStatus(
          organizationId: item.organizationId,
          uid: item.uid,
          quoteId: quote.id,
          status: OfflineSyncStatus.synced,
        );
      case OfflineEntityType.brandingLogo:
        final path = item.payload['logoLocalPath'] as String?;
        if (path == null || path.isEmpty) {
          throw Exception('Ruta local de logo ausente');
        }
        final file = File(path);
        if (!await file.exists()) {
          throw Exception('Archivo de logo local no encontrado');
        }
        final bytes = await file.readAsBytes();
        final uploaded = await BrandingStorageService.instance.uploadOrgLogo(
          orgId: item.organizationId,
          uid: item.uid,
          bytes: Uint8List.fromList(bytes),
        );
        final quoteId = item.payload['quoteId'] as String?;
        // Logo solo de cotización: actualiza la quote, no la identidad de empresa.
        if (quoteId != null && quoteId.isNotEmpty) {
          final local = await OfflineLocalStore.instance.getQuote(
            organizationId: item.organizationId,
            uid: item.uid,
            quoteId: quoteId,
          );
          final base = local?.quote ??
              await CloudCotizacionRepository.instance.getQuoteRemoteOnly(
                quoteId,
              );
          if (base != null) {
            final updated = base.copyWith(logoPath: uploaded.url);
            await CloudCotizacionRepository.instance.saveQuoteRemoteOnly(
              updated,
              isNew: false,
            );
            await OfflineLocalStore.instance.upsertQuote(
              uid: item.uid,
              quote: updated,
              status: OfflineSyncStatus.synced,
            );
          }
          break;
        }
        final brandingMap =
            Map<String, dynamic>.from(item.payload['branding'] as Map? ?? {});
        final branding = OrgBranding.fromMap(brandingMap).copyWith(
          logoUrl: uploaded.url,
          logoStoragePath: uploaded.storagePath,
        );
        await OrganizationService.instance.updateBranding(
          orgId: item.organizationId,
          branding: branding.toMap(),
        );
        await BrandingLocalCache.instance.saveLogoBytes(
          organizationId: item.organizationId,
          uid: item.uid,
          bytes: Uint8List.fromList(bytes),
          branding: branding,
          pendingUpload: false,
        );
      case OfflineEntityType.brandingConfig:
        final branding = OrgBranding.fromMap(item.payload);
        await OrganizationService.instance.updateBranding(
          orgId: item.organizationId,
          branding: branding.toMap(),
        );
        await BrandingLocalCache.instance.saveBrandingConfig(
          organizationId: item.organizationId,
          uid: item.uid,
          branding: branding,
          pending: false,
        );
    }
  }

  /// Clave idempotente estable por entidad + operación + versión local.
  static String idempotencyKey({
    required OfflineEntityType type,
    required String entityId,
    required OfflineOperation op,
    required String revision,
  }) => '${type.id}:${op.id}:$entityId:$revision';

  /// Útil para depuración / tests.
  String encodePayload(Map<String, dynamic> map) => jsonEncode(map);
}
