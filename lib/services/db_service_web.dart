import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cotizacion.dart';
import '../models/servicio.dart';

/// Implementación de DBService usando SharedPreferences (Web).
class DBService {
  static final DBService instance = DBService._init();
  static const _keyCotizaciones = 'cotizaciones_data';

  DBService._init();

  Future<void> get database async {}

  Future<SharedPreferences> get _prefs async =>
      await SharedPreferences.getInstance();

  Future<int> getProximoNumero() async {
    final prefs = await _prefs;
    return prefs.getInt('ultimo_numero_cotizacion') ?? 1;
  }

  Future<void> incrementarNumero() async {
    final prefs = await _prefs;
    final actual = prefs.getInt('ultimo_numero_cotizacion') ?? 1;
    await prefs.setInt('ultimo_numero_cotizacion', actual + 1);
  }

  Future<void> configurarNumero(int nuevoValor) async {
    final prefs = await _prefs;
    await prefs.setInt('ultimo_numero_cotizacion', nuevoValor);
  }

  Future<String> getPrefijo() async {
    final prefs = await _prefs;
    return prefs.getString('prefijo_cotizacion') ?? 'COT';
  }

  Future<void> configurarPrefijo(String prefijo) async {
    final prefs = await _prefs;
    await prefs.setString('prefijo_cotizacion', prefijo);
  }

  Future<void> insertarCotizacion(Cotizacion cot) async {
    final prefs = await _prefs;
    final list = await obtenerTodas();
    final idx = list.indexWhere((c) => c.id == cot.id);
    if (idx >= 0) {
      list[idx] = cot;
    } else {
      list.insert(0, cot);
    }
    final data = list.map((c) => _cotizacionToJson(c)).toList();
    await prefs.setString(_keyCotizaciones, jsonEncode(data));
  }

  Map<String, dynamic> _cotizacionToJson(Cotizacion c) {
    final m = c.toMap();
    m['servicios'] = c.servicios.map((s) => s.toMap()).toList();
    return m;
  }

  Future<List<Cotizacion>> obtenerTodas() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_keyCotizaciones);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>? ?? [];
      return list.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        final serviciosList =
            (m['servicios'] as List<dynamic>?)
                ?.map(
                  (s) => Servicio.fromMap(Map<String, dynamic>.from(s as Map)),
                )
                .toList() ??
            [];
        m.remove('servicios');
        return Cotizacion.fromMap(m, serviciosList);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> eliminarCotizacion(String id) async {
    final prefs = await _prefs;
    final list = await obtenerTodas();
    list.removeWhere((c) => c.id == id);
    final data = list.map((c) => _cotizacionToJson(c)).toList();
    await prefs.setString(_keyCotizaciones, jsonEncode(data));
  }
}
