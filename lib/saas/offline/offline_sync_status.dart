/// Estado de sincronización de un registro local con Firebase.
enum OfflineSyncStatus {
  /// Solo en dispositivo; aún no confirmado en Firebase.
  pending('pending'),

  /// Confirmado en Firebase (última versión conocida).
  synced('synced'),

  /// Último intento falló; se reintentará.
  error('error'),

  /// Versión remota distinta; requiere resolución explícita.
  conflict('conflict');

  const OfflineSyncStatus(this.id);
  final String id;

  static OfflineSyncStatus fromId(String? raw) {
    return OfflineSyncStatus.values.firstWhere(
      (e) => e.id == raw,
      orElse: () => OfflineSyncStatus.pending,
    );
  }
}

/// Tipo de entidad en la cola de sincronización.
enum OfflineEntityType {
  client('client'),
  quote('quote'),
  brandingLogo('branding_logo'),
  brandingConfig('branding_config');

  const OfflineEntityType(this.id);
  final String id;

  static OfflineEntityType fromId(String raw) {
    return OfflineEntityType.values.firstWhere(
      (e) => e.id == raw,
      orElse: () => OfflineEntityType.quote,
    );
  }
}

enum OfflineOperation {
  upsert('upsert'),
  delete('delete'),
  uploadFile('upload_file');

  const OfflineOperation(this.id);
  final String id;

  static OfflineOperation fromId(String raw) {
    return OfflineOperation.values.firstWhere(
      (e) => e.id == raw,
      orElse: () => OfflineOperation.upsert,
    );
  }
}

/// Estado agregado mostrado en la UI.
enum OfflineUiStatus { online, offline, syncing, pendingChanges, syncError }
