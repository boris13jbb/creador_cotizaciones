import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:universal_io/io.dart';

import '../models/org_branding.dart';
import '../models/org_client.dart';
import '../models/quote.dart';
import '../services/auth_service.dart';
import '../services/branding_storage_service.dart';
import '../services/client_repository.dart';
import '../services/cloud_cotizacion_repository.dart';
import '../services/organization_service.dart';
import '../services/quote_create_service.dart';
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

  Future<bool> canReachFirebase() =>
      ConnectivityMonitor.instance.probeFirebase();

  /// Último error de ítem de cola (para UI).
  String? lastItemError;

  /// [forceRetry]: sync manual del usuario — ignora backoff y repara cola huérfana.
  Future<int> syncPending({
    required String organizationId,
    required String uid,
    bool forceRetry = false,
  }) async {
    if (_running) {
      debugPrint('offline sync abort: already_running');
      lastItemError = 'Sincronización ya en curso.';
      return 0;
    }
    final reachable = await canReachFirebase();
    if (!reachable) {
      debugPrint('offline sync abort: firebase_unreachable');
      lastItemError = 'Sin conexión con Firebase.';
      return 0;
    }

    // No vaciar ni marcar la cola si Auth aún no puede firmar callables.
    if (!AuthService.instance.hasCallableAuthSession) {
      lastItemError =
          'Sesión no lista para sincronizar. Espera o vuelve a iniciar sesión.';
      debugPrint('offline sync abort: sin sesión callable');
      return 0;
    }
    try {
      await AuthService.instance.ensureCallableAuth(forceRefresh: true);
    } on CallableAuthException catch (e) {
      lastItemError = e.message;
      debugPrint('offline sync abort auth[${e.code}]: ${e.message}');
      return 0;
    } catch (e) {
      lastItemError = 'No se pudo preparar la sesión para sincronizar.';
      debugPrint('offline sync abort auth: $e');
      return 0;
    }

    _running = true;
    var completed = 0;
    // Conservar error previo hasta saber si hay trabajo / resultado nuevo.
    final previousError = lastItemError;
    lastItemError = null;
    try {
      final diag = await OfflineLocalStore.instance.queueDiagnostics(
        organizationId: organizationId,
        uid: uid,
      );
      debugPrint('offline sync diag: $diag forceRetry=$forceRetry');

      // Cotizaciones «Solo dispositivo» sin fila en sync_queue → reencolar.
      if (diag.orphanLocalQuotes > 0) {
        final repaired = await OfflineLocalStore.instance
            .ensureQueueForUnsyncedQuotes(
              organizationId: organizationId,
              uid: uid,
            );
        debugPrint(
          'offline sync repair: orphan=${diag.orphanLocalQuotes} '
          'enqueued=$repaired',
        );
      }

      var queue = await OfflineLocalStore.instance.pendingQueue(
        organizationId: organizationId,
        uid: uid,
        forceIgnoreBackoff: forceRetry,
      );

      if (queue.isEmpty && !forceRetry && diag.blockedByBackoff > 0) {
        // Sync automática respetó backoff; el usuario puede forzar.
        lastItemError =
            'Hay ${diag.blockedByBackoff} cambio(s) en espera de reintento. '
            'Pulsa Sincronizar de nuevo para forzar.';
        debugPrint(
          'offline sync: no_eligible_backoff=${diag.blockedByBackoff}',
        );
        return 0;
      }

      if (queue.isEmpty && forceRetry && diag.incompleteQueue > 0) {
        // Por si el diagnóstico cambió tras repair.
        queue = await OfflineLocalStore.instance.pendingQueue(
          organizationId: organizationId,
          uid: uid,
          forceIgnoreBackoff: true,
        );
      }

      if (queue.isEmpty) {
        final after = await OfflineLocalStore.instance.queueDiagnostics(
          organizationId: organizationId,
          uid: uid,
        );
        if (after.pendingLocalQuotes > 0 && after.incompleteQuoteQueue == 0) {
          lastItemError =
              'Hay ${after.pendingLocalQuotes} cotiz. locales sin cola. '
              'Reintento de reparación no dejó elementos elegibles.';
        } else if (after.incompleteQueue == 0 &&
            after.pendingLocalQuotes == 0) {
          lastItemError = previousError;
          debugPrint('offline sync: nothing_pending');
        } else {
          lastItemError =
              'No hay elementos elegibles ahora '
              '(cola=${after.incompleteQueue}, '
              'locales=${after.pendingLocalQuotes}).';
        }
        debugPrint('offline sync: empty_queue selected=0 diag=$after');
        return 0;
      }

      debugPrint('offline sync: selected=${queue.length} items');
      for (final item in queue) {
        try {
          debugPrint(
            'offline sync process type=${item.entityType.id} '
            'attempts=${item.attempts}',
          );
          await _processItem(item);
          await OfflineLocalStore.instance.markQueueCompleted(item.id);
          completed++;
        } catch (e, st) {
          debugPrint('offline sync item ${item.id}: $e\n$st');
          lastItemError = _safeSyncErrorMessage(e);
          await OfflineLocalStore.instance.markQueueFailed(
            item.id,
            lastItemError!,
          );
          if (item.entityType == OfflineEntityType.quote) {
            final isConflict = lastItemError!.contains('Conflicto');
            await OfflineLocalStore.instance.markQuoteStatus(
              organizationId: item.organizationId,
              uid: item.uid,
              quoteId: item.entityId,
              status: isConflict
                  ? OfflineSyncStatus.conflict
                  : OfflineSyncStatus.error,
              conflictPayloadJson: isConflict
                  ? '{"source":"sync_queue"}'
                  : null,
            );
          }
          if (_isAuthFailure(e)) break;
        }
      }
      debugPrint(
        'offline sync done: completed=$completed selected=${queue.length} '
        'lastError=${lastItemError ?? "(none)"}',
      );
    } finally {
      _running = false;
    }
    return completed;
  }

  static bool _isAuthFailure(Object e) {
    if (e is CallableAuthException) return e.isUnauthenticated;
    if (e is QuoteCreateException) return e.isUnauthenticated;
    final t = e.toString().toLowerCase();
    return t.contains('unauthenticated') || t.contains('debes iniciar sesión');
  }

  static String _safeSyncErrorMessage(Object e) {
    if (e is QuoteCreateException) return '[${e.code}] ${e.message}';
    if (e is QuoteLimitExceededException) return e.message;
    if (e is CallableAuthException) return '[${e.code}] ${e.message}';
    return e.toString().replaceFirst('Exception: ', '');
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
        // Tras jsonEncode/jsonDecode el flag debe seguir siendo true; si se pierde,
        // un upsert cliente choca con rules `create: false` y la cola nunca avanza.
        final isNew = QuoteCreateService.payloadMarksNewQuote(item.payload);
        // Evitar sobrescritura silenciosa si el remoto cambió en otro dispositivo.
        if (!isNew) {
          final remote = await CloudCotizacionRepository.instance
              .getQuoteRemoteOnly(quote.id);
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
        final quoteId = item.payload['quoteId'] as String?;
        // Logo solo de cotización: ruta Storage distinta; no toca logo.png ni org.
        if (quoteId != null && quoteId.isNotEmpty) {
          final uploaded = await BrandingStorageService.instance
              .uploadQuoteLogo(
                orgId: item.organizationId,
                quoteId: quoteId,
                uid: item.uid,
                bytes: Uint8List.fromList(bytes),
              );
          final local = await OfflineLocalStore.instance.getQuote(
            organizationId: item.organizationId,
            uid: item.uid,
            quoteId: quoteId,
          );
          final base =
              local?.quote ??
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
        final uploaded = await BrandingStorageService.instance.uploadOrgLogo(
          orgId: item.organizationId,
          uid: item.uid,
          bytes: Uint8List.fromList(bytes),
        );
        final brandingMap = Map<String, dynamic>.from(
          item.payload['branding'] as Map? ?? {},
        );
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
