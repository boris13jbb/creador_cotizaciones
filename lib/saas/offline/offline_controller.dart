import 'dart:async';

import 'package:flutter/foundation.dart';

import 'connectivity_monitor.dart';
import 'offline_local_store.dart';
import 'offline_sync_service.dart';
import 'offline_sync_status.dart';

/// Estado de conexión/sincronización para la UI.
class OfflineController extends ChangeNotifier {
  OfflineController._();
  static final OfflineController instance = OfflineController._();

  String? _uid;
  String? _organizationId;
  StreamSubscription<bool>? _connSub;
  OfflineUiStatus _status = OfflineUiStatus.online;
  int pendingOps = 0;
  int pendingQuotes = 0;
  int pendingFiles = 0;
  String? lastError;
  bool _syncing = false;

  OfflineUiStatus get status => _status;
  bool get hasPending => pendingOps > 0 || pendingQuotes > 0 || pendingFiles > 0;

  Future<void> bindSession({
    required String? uid,
    required String? organizationId,
  }) async {
    _uid = uid;
    _organizationId = organizationId;
    await ConnectivityMonitor.instance.start();
    await _connSub?.cancel();
    _connSub = ConnectivityMonitor.instance.onChanged.listen((_) {
      unawaited(refresh());
    });
    await refresh();
    if (ConnectivityMonitor.instance.isEffectivelyOnline &&
        uid != null &&
        organizationId != null) {
      unawaited(syncNow());
    }
  }

  Future<void> refresh() async {
    final uid = _uid;
    final orgId = _organizationId;
    if (uid == null || orgId == null || orgId.isEmpty) {
      _status = ConnectivityMonitor.instance.isEffectivelyOnline
          ? OfflineUiStatus.online
          : OfflineUiStatus.offline;
      pendingOps = 0;
      pendingQuotes = 0;
      pendingFiles = 0;
      notifyListeners();
      return;
    }

    try {
      pendingOps = await OfflineLocalStore.instance.countPending(
        organizationId: orgId,
        uid: uid,
      );
      pendingQuotes = await OfflineLocalStore.instance.countPendingQuotes(
        organizationId: orgId,
        uid: uid,
      );
      pendingFiles = await OfflineLocalStore.instance.countPendingFiles(
        organizationId: orgId,
        uid: uid,
      );
    } catch (e) {
      // Web u otros entornos sin SQLite.
      debugPrint('offline refresh: $e');
      pendingOps = 0;
      pendingQuotes = 0;
      pendingFiles = 0;
    }

    if (_syncing) {
      _status = OfflineUiStatus.syncing;
    } else if (!ConnectivityMonitor.instance.hasNetworkInterface ||
        !ConnectivityMonitor.instance.firebaseReachable) {
      _status = OfflineUiStatus.offline;
    } else if (lastError != null && hasPending) {
      _status = OfflineUiStatus.syncError;
    } else if (hasPending) {
      _status = OfflineUiStatus.pendingChanges;
    } else {
      _status = OfflineUiStatus.online;
    }
    notifyListeners();
  }

  Future<void> syncNow() async {
    final uid = _uid;
    final orgId = _organizationId;
    if (uid == null || orgId == null || orgId.isEmpty) return;
    if (_syncing) return;

    _syncing = true;
    lastError = null;
    _status = OfflineUiStatus.syncing;
    notifyListeners();
    try {
      await OfflineSyncService.instance.syncPending(
        organizationId: orgId,
        uid: uid,
      );
      lastError = OfflineSyncService.instance.lastItemError;
    } catch (e) {
      lastError = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _syncing = false;
      await refresh();
    }
  }

  /// Antes de cerrar sesión: true si hay pendientes que el usuario debe conocer.
  Future<bool> hasUnsyncedWork() async {
    final uid = _uid;
    final orgId = _organizationId;
    if (uid == null || orgId == null) return false;
    try {
      final n = await OfflineLocalStore.instance.countAllPendingForUser(
        uid: uid,
        organizationId: orgId,
      );
      return n > 0 || pendingQuotes > 0 || pendingFiles > 0;
    } catch (_) {
      return false;
    }
  }

  Future<void> onSignOut({required String uid}) async {
    try {
      await OfflineLocalStore.instance.noteSessionEnded(uid: uid);
    } catch (_) {}
    _uid = null;
    _organizationId = null;
    await refresh();
  }

  String statusLabel() => switch (_status) {
    OfflineUiStatus.online => 'En línea',
    OfflineUiStatus.offline => 'Sin conexión',
    OfflineUiStatus.syncing => 'Sincronizando…',
    OfflineUiStatus.pendingChanges => 'Cambios pendientes',
    OfflineUiStatus.syncError => 'Error de sincronización',
  };
}
