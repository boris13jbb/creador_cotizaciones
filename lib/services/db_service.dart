import '../models/cotizacion.dart';
import '../saas/services/cloud_cotizacion_repository.dart';

/// Fachada de datos SaaS (Firestore). Mantiene la API usada por las pantallas.
class DBService {
  static final DBService instance = DBService._();
  DBService._();

  final _cloud = CloudCotizacionRepository.instance;

  Future<void> get database async {}

  Future<void> insertarCotizacion(Cotizacion cot) => _cloud.insertarCotizacion(cot);

  Future<List<Cotizacion>> obtenerTodas() => _cloud.obtenerTodas();

  Future<void> eliminarCotizacion(String id) => _cloud.eliminarCotizacion(id);

  Future<int> getProximoNumero() => _cloud.getProximoNumero();

  Future<void> incrementarNumero() => _cloud.incrementarNumero();

  Future<void> configurarNumero(int v) => _cloud.configurarNumero(v);

  Future<String> getPrefijo() => _cloud.getPrefijo();

  Future<void> configurarPrefijo(String p) => _cloud.configurarPrefijo(p);
}
