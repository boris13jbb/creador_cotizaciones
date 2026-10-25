import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import '../models/org_branding.dart';
import '../models/org_client.dart';
import '../models/quote.dart';
import 'offline_database.dart';
import 'offline_sync_status.dart';

/// Fila de cola de sincronización persistente.
class SyncQueueItem {
  final int id;
  final String organizationId;
  final String uid;
  final OfflineEntityType entityType;
  final String entityId;
  final OfflineOperation operation;
  final Map<String, dynamic> payload;
  final String idempotencyKey;
  final int attempts;
  final String? lastError;
  final DateTime createdAt;
  final DateTime nextAttemptAt;

  const SyncQueueItem({
    required this.id,
    required this.organizationId,
    required this.uid,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
    required this.idempotencyKey,
    required this.attempts,
    this.lastError,
    required this.createdAt,
    required this.nextAttemptAt,
  });

  factory SyncQueueItem.fromRow(Map<String, dynamic> row) {
    return SyncQueueItem(
      id: row['id'] as int,
      organizationId: row['organization_id'] as String,
      uid: row['uid'] as String,
      entityType: OfflineEntityType.fromId(row['entity_type'] as String),
      entityId: row['entity_id'] as String,
      operation: OfflineOperation.fromId(row['operation'] as String),
      payload: Map<String, dynamic>.from(
        jsonDecode(row['payload_json'] as String) as Map,
      ),
      idempotencyKey: row['idempotency_key'] as String,
      attempts: row['attempts'] as int? ?? 0,
      lastError: row['last_error'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      nextAttemptAt: DateTime.parse(row['next_attempt_at'] as String),
    );
  }
}

/// Cotización local con metadatos de sync.
class LocalQuoteRecord {
  final Quote quote;
  final OfflineSyncStatus syncStatus;
  final String? conflictPayloadJson;

  const LocalQuoteRecord({
    required this.quote,
    required this.syncStatus,
    this.conflictPayloadJson,
  });
}

/// Persistencia local multiempresa (SQLite) + cola de operaciones.
class OfflineLocalStore {
  OfflineLocalStore._();
  static final OfflineLocalStore instance = OfflineLocalStore._();

  Future<void> upsertClient({
    required String uid,
    required OrgClient client,
    OfflineSyncStatus status = OfflineSyncStatus.pending,
  }) async {
    final db = await OfflineDatabase.instance.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.insert('local_clients', {
      'id': client.id,
      'organization_id': client.organizationId,
      'uid': uid,
      'remote_id': client.id,
      'payload_json': jsonEncode(client.toMap()),
      'sync_status': status.id,
      'version': 1,
      'created_at': client.createdAt.toUtc().toIso8601String(),
      'updated_at': client.updatedAt.toUtc().toIso8601String().isEmpty
          ? now
          : client.updatedAt.toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<OrgClient>> listClients({
    required String organizationId,
    required String uid,
  }) async {
    final db = await OfflineDatabase.instance.database;
    final rows = await db.query(
      'local_clients',
      where: 'organization_id = ? AND uid = ?',
      whereArgs: [organizationId, uid],
      orderBy: 'updated_at DESC',
    );
    return rows
        .map(
          (r) => OrgClient.fromMap(
            Map<String, dynamic>.from(
              jsonDecode(r['payload_json'] as String) as Map,
            ),
          ),
        )
        .toList();
  }

  Future<OrgClient?> getClient({
    required String organizationId,
    required String uid,
    required String clientId,
  }) async {
    final db = await OfflineDatabase.instance.database;
    final rows = await db.query(
      'local_clients',
      where: 'organization_id = ? AND uid = ? AND id = ?',
      whereArgs: [organizationId, uid, clientId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return OrgClient.fromMap(
      Map<String, dynamic>.from(
        jsonDecode(rows.first['payload_json'] as String) as Map,
      ),
    );
  }

  Future<void> upsertQuote({
    required String uid,
    required Quote quote,
    OfflineSyncStatus status = OfflineSyncStatus.pending,
    String? conflictPayloadJson,
  }) async {
    final db = await OfflineDatabase.instance.database;
    await db.insert('local_quotes', {
      'id': quote.id,
      'organization_id': quote.organizationId,
      'uid': uid,
      'remote_id': quote.id,
      'payload_json': jsonEncode(quote.toMap()),
      'sync_status': status.id,
      'version': quote.version,
      'conflict_payload_json': conflictPayloadJson,
      'created_at': quote.createdAt.toUtc().toIso8601String(),
      'updated_at': quote.updatedAt.toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<LocalQuoteRecord>> listQuotes({
    required String organizationId,
    required String uid,
  }) async {
    final db = await OfflineDatabase.instance.database;
    final rows = await db.query(
      'local_quotes',
      where: 'organization_id = ? AND uid = ?',
      whereArgs: [organizationId, uid],
      orderBy: 'updated_at DESC',
    );
    return rows.map(_quoteFromRow).toList();
  }

  Future<LocalQuoteRecord?> getQuote({
    required String organizationId,
    required String uid,
    required String quoteId,
  }) async {
    final db = await OfflineDatabase.instance.database;
    final rows = await db.query(
      'local_quotes',
      where: 'organization_id = ? AND uid = ? AND id = ?',
      whereArgs: [organizationId, uid, quoteId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _quoteFromRow(rows.first);
  }

  LocalQuoteRecord _quoteFromRow(Map<String, dynamic> row) {
    final quote = Quote.fromMap(
      Map<String, dynamic>.from(
        jsonDecode(row['payload_json'] as String) as Map,
      ),
    );
    return LocalQuoteRecord(
      quote: quote,
      syncStatus: OfflineSyncStatus.fromId(row['sync_status'] as String?),
      conflictPayloadJson: row['conflict_payload_json'] as String?,
    );
  }

  Future<void> markQuoteStatus({
    required String organizationId,
    required String uid,
    required String quoteId,
    required OfflineSyncStatus status,
    String? conflictPayloadJson,
  }) async {
    final db = await OfflineDatabase.instance.database;
    await db.update(
      'local_quotes',
      {
        'sync_status': status.id,
        if (conflictPayloadJson != null)
          'conflict_payload_json': conflictPayloadJson,
        if (status == OfflineSyncStatus.synced) 'conflict_payload_json': null,
      },
      where: 'organization_id = ? AND uid = ? AND id = ?',
      whereArgs: [organizationId, uid, quoteId],
    );
  }

  Future<void> markClientStatus({
    required String organizationId,
    required String uid,
    required String clientId,
    required OfflineSyncStatus status,
  }) async {
    final db = await OfflineDatabase.instance.database;
    await db.update(
      'local_clients',
      {'sync_status': status.id},
      where: 'organization_id = ? AND uid = ? AND id = ?',
      whereArgs: [organizationId, uid, clientId],
    );
  }

  Future<void> saveBranding({
    required String organizationId,
    required String uid,
    required OrgBranding branding,
    String? logoLocalPath,
    bool logoPendingUpload = false,
    OfflineSyncStatus status = OfflineSyncStatus.synced,
  }) async {
    final db = await OfflineDatabase.instance.database;
    await db.insert('local_branding', {
      'organization_id': organizationId,
      'uid': uid,
      'payload_json': jsonEncode(branding.toMap()),
      'logo_local_path': logoLocalPath,
      'logo_pending_upload': logoPendingUpload ? 1 : 0,
      'sync_status': status.id,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<({OrgBranding branding, String? logoLocalPath, bool logoPending})?>
  getBranding({required String organizationId, required String uid}) async {
    final db = await OfflineDatabase.instance.database;
    final rows = await db.query(
      'local_branding',
      where: 'organization_id = ? AND uid = ?',
      whereArgs: [organizationId, uid],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return (
      branding: OrgBranding.fromMap(
        Map<String, dynamic>.from(
          jsonDecode(row['payload_json'] as String) as Map,
        ),
      ),
      logoLocalPath: row['logo_local_path'] as String?,
      logoPending: (row['logo_pending_upload'] as int? ?? 0) == 1,
    );
  }

  /// Encola operación idempotente. Si la clave ya existe pendiente, no duplica.
  Future<void> enqueue({
    required String organizationId,
    required String uid,
    required OfflineEntityType entityType,
    required String entityId,
    required OfflineOperation operation,
    required Map<String, dynamic> payload,
    required String idempotencyKey,
  }) async {
    final db = await OfflineDatabase.instance.database;
    final now = DateTime.now().toUtc();
    try {
      await db.insert('sync_queue', {
        'organization_id': organizationId,
        'uid': uid,
        'entity_type': entityType.id,
        'entity_id': entityId,
        'operation': operation.id,
        'payload_json': jsonEncode(payload),
        'idempotency_key': idempotencyKey,
        'attempts': 0,
        'last_error': null,
        'created_at': now.toIso8601String(),
        'next_attempt_at': now.toIso8601String(),
        'completed_at': null,
      });
    } catch (e) {
      // UNIQUE(idempotency_key): actualizar payload pendiente sin duplicar.
      final updated = await db.update(
        'sync_queue',
        {
          'payload_json': jsonEncode(payload),
          'next_attempt_at': now.toIso8601String(),
          'last_error': null,
        },
        where: 'idempotency_key = ? AND completed_at IS NULL',
        whereArgs: [idempotencyKey],
      );
      if (updated == 0) {
        debugPrint('offline enqueue skipped/completed: $idempotencyKey ($e)');
      }
    }
  }

  Future<List<SyncQueueItem>> pendingQueue({
    required String organizationId,
    required String uid,
    int limit = 50,
  }) async {
    final db = await OfflineDatabase.instance.database;
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = await db.query(
      'sync_queue',
      where:
          'organization_id = ? AND uid = ? AND completed_at IS NULL '
          'AND next_attempt_at <= ?',
      whereArgs: [organizationId, uid, now],
      orderBy: 'id ASC',
      limit: limit,
    );
    return rows.map(SyncQueueItem.fromRow).toList();
  }

  Future<int> countPending({
    required String organizationId,
    required String uid,
  }) async {
    final db = await OfflineDatabase.instance.database;
    final r = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM sync_queue '
      'WHERE organization_id = ? AND uid = ? AND completed_at IS NULL',
      [organizationId, uid],
    );
    return (r.first['c'] as int?) ?? 0;
  }

  Future<int> countPendingQuotes({
    required String organizationId,
    required String uid,
  }) async {
    final db = await OfflineDatabase.instance.database;
    final r = await db.rawQuery(
      "SELECT COUNT(*) AS c FROM local_quotes "
      "WHERE organization_id = ? AND uid = ? AND sync_status != 'synced'",
      [organizationId, uid],
    );
    return (r.first['c'] as int?) ?? 0;
  }

  Future<int> countPendingFiles({
    required String organizationId,
    required String uid,
  }) async {
    final db = await OfflineDatabase.instance.database;
    final r = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM local_branding '
      'WHERE organization_id = ? AND uid = ? AND logo_pending_upload = 1',
      [organizationId, uid],
    );
    return (r.first['c'] as int?) ?? 0;
  }

  Future<void> markQueueCompleted(int id) async {
    final db = await OfflineDatabase.instance.database;
    await db.update(
      'sync_queue',
      {'completed_at': DateTime.now().toUtc().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markQueueFailed(int id, String error, {Duration? backoff}) async {
    final db = await OfflineDatabase.instance.database;
    final rows = await db.query(
      'sync_queue',
      columns: ['attempts'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    final attempts = (rows.isEmpty ? 0 : (rows.first['attempts'] as int? ?? 0)) + 1;
    final delay = backoff ?? Duration(seconds: (1 << attempts.clamp(0, 6)) * 5);
    final next = DateTime.now().toUtc().add(delay);
    await db.update(
      'sync_queue',
      {
        'attempts': attempts,
        'last_error': error.length > 500 ? error.substring(0, 500) : error,
        'next_attempt_at': next.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Cuenta pendientes de la sesión activa (antes de cerrar sesión).
  Future<int> countAllPendingForUser({
    required String uid,
    required String organizationId,
  }) => countPending(organizationId: organizationId, uid: uid);

  /// No borra datos pendientes: solo deja de exponerlos a otra cuenta.
  /// Los registros siguen filtrados por uid + organization_id.
  Future<void> noteSessionEnded({required String uid}) async {
    final db = await OfflineDatabase.instance.database;
    await db.insert('offline_meta', {
      'key': 'last_uid',
      'value': uid,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
