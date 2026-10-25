import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Base SQLite persistente del modo offline SaaS (separada del legado `cotizaciones.db`).
///
/// Esquema v1: clientes, cotizaciones, branding, cola de sync e índices por org/uid.
class OfflineDatabase {
  OfflineDatabase._();
  static final OfflineDatabase instance = OfflineDatabase._();

  static const dbName = 'cotiapp_offline.db';
  static const schemaVersion = 1;

  Database? _db;
  bool _factoryReady = false;

  /// Inicializa factory FFI en desktop; en Android/iOS usa sqflite nativo.
  Future<void> ensureFactory() async {
    if (_factoryReady || kIsWeb) return;
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    _factoryReady = true;
  }

  Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError(
        'El almacenamiento offline SQLite no está disponible en Web. '
        'Usa la app Android/Windows instalada.',
      );
    }
    if (_db != null) return _db!;
    await ensureFactory();
    final dir = await getDatabasesPath();
    final path = p.join(dir, dbName);
    _db = await openDatabase(
      path,
      version: schemaVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return _db!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE local_clients (
        id TEXT NOT NULL,
        organization_id TEXT NOT NULL,
        uid TEXT NOT NULL,
        remote_id TEXT,
        payload_json TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        version INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (organization_id, id)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_local_clients_org_sync '
      'ON local_clients(organization_id, sync_status)',
    );
    await db.execute(
      'CREATE INDEX idx_local_clients_uid ON local_clients(uid)',
    );

    await db.execute('''
      CREATE TABLE local_quotes (
        id TEXT NOT NULL,
        organization_id TEXT NOT NULL,
        uid TEXT NOT NULL,
        remote_id TEXT,
        payload_json TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        version INTEGER NOT NULL DEFAULT 1,
        conflict_payload_json TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (organization_id, id)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_local_quotes_org_sync '
      'ON local_quotes(organization_id, sync_status)',
    );
    await db.execute(
      'CREATE INDEX idx_local_quotes_updated '
      'ON local_quotes(organization_id, updated_at DESC)',
    );

    await db.execute('''
      CREATE TABLE local_branding (
        organization_id TEXT NOT NULL PRIMARY KEY,
        uid TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        logo_local_path TEXT,
        logo_pending_upload INTEGER NOT NULL DEFAULT 0,
        sync_status TEXT NOT NULL DEFAULT 'synced',
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        organization_id TEXT NOT NULL,
        uid TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        idempotency_key TEXT NOT NULL UNIQUE,
        attempts INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        created_at TEXT NOT NULL,
        next_attempt_at TEXT NOT NULL,
        completed_at TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_sync_queue_pending '
      'ON sync_queue(organization_id, completed_at, next_attempt_at)',
    );

    await db.execute('''
      CREATE TABLE offline_meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Migraciones futuras: incrementar [schemaVersion] y aplicar ALTER aquí.
  }

  @visibleForTesting
  Future<void> closeForTests() async {
    await _db?.close();
    _db = null;
  }
}
