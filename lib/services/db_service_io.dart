import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cotizacion.dart';
import '../models/servicio.dart';

/// Implementación de DBService usando SQLite (Android, iOS, macOS, Windows, Linux).
class DBService {
  static final DBService instance = DBService._init();
  static Database? _database;

  DBService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('cotizaciones.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 6,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE cotizaciones (
        id TEXT PRIMARY KEY,
        numero TEXT,
        fecha TEXT,
        cliente TEXT,
        ubicacion TEXT,
        tipoServicio TEXT,
        cantidadEquipos TEXT,
        tiempoEstimado TEXT,
        descripcion TEXT,
        total REAL,
        logoPath TEXT,
        incluye TEXT,
        noIncluye TEXT,
        notas TEXT,
        subtitulo TEXT,
        validezDias INTEGER,
        footerText TEXT,
        firmaTecnicoLabel TEXT,
        firmaClienteLabel TEXT,
        formaPagoJson TEXT,
        camposExtra TEXT,
        coloresJson TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE servicios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cotizacionId TEXT,
        nombre TEXT,
        descripcion TEXT,
        precio REAL,
        FOREIGN KEY (cotizacionId) REFERENCES cotizaciones (id) ON DELETE CASCADE
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try { await db.execute('ALTER TABLE cotizaciones ADD COLUMN subtitulo TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE cotizaciones ADD COLUMN validezDias INTEGER'); } catch (_) {}
      try { await db.execute('ALTER TABLE cotizaciones ADD COLUMN footerText TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE cotizaciones ADD COLUMN firmaTecnicoLabel TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE cotizaciones ADD COLUMN firmaClienteLabel TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE cotizaciones ADD COLUMN formaPagoJson TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE cotizaciones ADD COLUMN camposExtra TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE cotizaciones ADD COLUMN coloresJson TEXT'); } catch (_) {}
    }
    // Versiones 3-5 agregaban tabla resumes (ahora en proyecto creador_cv).
    // Se mantienen como no-op para no romper bases existentes.
  }

  Future<int> getProximoNumero() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('ultimo_numero_cotizacion') ?? 1;
  }

  Future<void> incrementarNumero() async {
    final prefs = await SharedPreferences.getInstance();
    final actual = prefs.getInt('ultimo_numero_cotizacion') ?? 1;
    await prefs.setInt('ultimo_numero_cotizacion', actual + 1);
  }

  Future<void> configurarNumero(int nuevoValor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('ultimo_numero_cotizacion', nuevoValor);
  }

  Future<String> getPrefijo() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('prefijo_cotizacion') ?? 'COT';
  }

  Future<void> configurarPrefijo(String prefijo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('prefijo_cotizacion', prefijo);
  }

  Future<void> insertarCotizacion(Cotizacion cot) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert(
        'cotizaciones',
        cot.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.delete('servicios', where: 'cotizacionId = ?', whereArgs: [cot.id]);
      for (var servicio in cot.servicios) {
        final m = servicio.toMap();
        m['cotizacionId'] = cot.id;
        await txn.insert('servicios', m);
      }
    });
  }

  Future<List<Cotizacion>> obtenerTodas() async {
    final db = await database;
    final result = await db.query('cotizaciones', orderBy: 'id DESC');
    if (result.isEmpty) return [];

    final cotizacionIds = result.map((r) => r['id'] as String).toList();
    final servicesResult = await db.query(
      'servicios',
      where: 'cotizacionId IN (${List.filled(cotizacionIds.length, '?').join(',')})',
      whereArgs: cotizacionIds,
    );

    final serviciosPorCotizacion = <String, List<Servicio>>{};
    for (var s in servicesResult) {
      final cotizacionId = s['cotizacionId'] as String;
      serviciosPorCotizacion.putIfAbsent(cotizacionId, () => []);
      serviciosPorCotizacion[cotizacionId]!.add(Servicio.fromMap(Map<String, dynamic>.from(s)));
    }

    return result.map((row) {
      final id = row['id'] as String;
      final servicios = serviciosPorCotizacion[id] ?? [];
      return Cotizacion.fromMap(Map<String, dynamic>.from(row), servicios);
    }).toList();
  }

  Future<void> eliminarCotizacion(String id) async {
    final db = await database;
    await db.delete('cotizaciones', where: 'id = ?', whereArgs: [id]);
  }
}
