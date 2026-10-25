import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:universal_io/io.dart';

import '../models/org_branding.dart';
import 'offline_local_store.dart';
import 'offline_sync_status.dart';

/// Caché de logo/branding en el almacenamiento de la app (persistente entre sesiones).
class BrandingLocalCache {
  BrandingLocalCache._();
  static final BrandingLocalCache instance = BrandingLocalCache._();

  Future<Directory?> _orgDir(String organizationId) async {
    if (kIsWeb) return null;
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, 'offline_branding', organizationId));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String?> saveLogoBytes({
    required String organizationId,
    required String uid,
    required Uint8List bytes,
    required OrgBranding branding,
    bool pendingUpload = false,
  }) async {
    final dir = await _orgDir(organizationId);
    if (dir == null) return null;
    final file = File(p.join(dir.path, 'logo.bin'));
    await file.writeAsBytes(bytes, flush: true);
    await OfflineLocalStore.instance.saveBranding(
      organizationId: organizationId,
      uid: uid,
      branding: branding,
      logoLocalPath: file.path,
      logoPendingUpload: pendingUpload,
      status: pendingUpload
          ? OfflineSyncStatus.pending
          : OfflineSyncStatus.synced,
    );
    return file.path;
  }

  Future<Uint8List?> loadLogoBytes({
    required String organizationId,
    required String uid,
  }) async {
    if (kIsWeb) return null;
    final cached = await OfflineLocalStore.instance.getBranding(
      organizationId: organizationId,
      uid: uid,
    );
    final path = cached?.logoLocalPath;
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  Future<void> saveBrandingConfig({
    required String organizationId,
    required String uid,
    required OrgBranding branding,
    bool pending = false,
  }) async {
    final existing = await OfflineLocalStore.instance.getBranding(
      organizationId: organizationId,
      uid: uid,
    );
    await OfflineLocalStore.instance.saveBranding(
      organizationId: organizationId,
      uid: uid,
      branding: branding,
      logoLocalPath: existing?.logoLocalPath,
      logoPendingUpload: existing?.logoPending ?? false,
      status: pending ? OfflineSyncStatus.pending : OfflineSyncStatus.synced,
    );
  }
}
