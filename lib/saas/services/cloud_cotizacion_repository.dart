import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/cotizacion.dart';
import '../../models/servicio.dart';
import '../config/saas_platform.dart';
import '../providers/auth_controller.dart';
import 'firestore_rest_client.dart';
import 'user_profile_service.dart';

/// Repositorio cloud de cotizaciones (SDK nativo o REST en Windows).
class CloudCotizacionRepository {
  CloudCotizacionRepository._();
  static final CloudCotizacionRepository instance = CloudCotizacionRepository._();

  FirebaseFirestore? _db;
  AuthController? _auth;

  void bindAuth(AuthController auth) => _auth = auth;

  FirebaseFirestore get _firestore {
    _db ??= FirebaseFirestore.instance;
    return _db!;
  }

  bool get _useRest {
    if (saasUseRestBackend) return true;
    return FirebaseAuth.instance.currentUser == null &&
        _auth?.restSession != null;
  }

  String get _uid {
    if (_useRest) {
      final rest = _auth?.restSession?.uid;
      if (rest != null && rest.isNotEmpty) return rest;
      throw Exception('Debes iniciar sesión para continuar.');
    }
    final native = FirebaseAuth.instance.currentUser?.uid;
    if (native != null) return native;
    throw Exception('Debes iniciar sesión para continuar.');
  }

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('users').doc(_uid).collection('cotizaciones');

  Future<void> insertarCotizacion(Cotizacion cot) async {
    if (_useRest) {
      final session = _auth!.restSession!;
      final profile = _auth!.profile;
      final actuales = await obtenerTodas();
      final exists = actuales.any((c) => c.id == cot.id);
      final max = profile?.maxCotizaciones ?? 5;
      if (!exists && actuales.length >= max) {
        throw Exception(
          'Límite del plan ${profile?.plan.label ?? 'Free'}: máximo $max cotizaciones. '
          'Actualiza a Pro para continuar.',
        );
      }
      await FirestoreRestClient.instance.upsertCotizacion(session: session, cot: cot);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Debes iniciar sesión para continuar.');
    final profile = await UserProfileService.instance.ensureProfile(user);
    final actuales = await obtenerTodas();
    final exists = actuales.any((c) => c.id == cot.id);
    if (!exists && actuales.length >= profile.maxCotizaciones) {
      throw Exception(
        'Límite del plan ${profile.plan.label}: máximo ${profile.maxCotizaciones} cotizaciones. '
        'Actualiza a Pro para continuar.',
      );
    }

    final data = cot.toMap();
    data['userId'] = _uid;
    data['servicios'] = cot.servicios.map((s) => s.toMap()).toList();
    data['updatedAt'] = DateTime.now().toIso8601String();
    await _col.doc(cot.id).set(data, SetOptions(merge: true));
  }

  Future<List<Cotizacion>> obtenerTodas() async {
    if (_useRest) {
      final session = _auth?.restSession;
      if (session == null) return [];
      return FirestoreRestClient.instance.listCotizaciones(session);
    }
    final snap = await _col.orderBy('updatedAt', descending: true).get();
    return snap.docs.map((d) => _fromDoc(d.data())).toList();
  }

  Future<void> eliminarCotizacion(String id) async {
    if (_useRest) {
      await FirestoreRestClient.instance.deleteCotizacion(_auth!.restSession!, id);
      return;
    }
    await _col.doc(id).delete();
  }

  Cotizacion _fromDoc(Map<String, dynamic> data) {
    final serviciosRaw = (data['servicios'] as List<dynamic>?) ?? [];
    final servicios = serviciosRaw
        .map((e) => Servicio.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    final map = Map<String, dynamic>.from(data);
    map.remove('servicios');
    map.remove('userId');
    map.remove('updatedAt');
    return Cotizacion.fromMap(map, servicios);
  }

  Future<int> getProximoNumero() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('ultimo_numero_cotizacion_$_uid') ?? 1;
  }

  Future<void> incrementarNumero() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'ultimo_numero_cotizacion_$_uid';
    final actual = prefs.getInt(key) ?? 1;
    await prefs.setInt(key, actual + 1);
  }

  Future<void> configurarNumero(int nuevoValor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('ultimo_numero_cotizacion_$_uid', nuevoValor);
  }

  Future<String> getPrefijo() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('prefijo_cotizacion_$_uid') ?? 'COT';
  }

  Future<void> configurarPrefijo(String prefijo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('prefijo_cotizacion_$_uid', prefijo);
  }
}
