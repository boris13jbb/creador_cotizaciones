import '../models/cotizacion.dart';
import '../saas/domain/org_enums.dart';
import '../saas/models/quote.dart';
import '../saas/services/cloud_cotizacion_repository.dart';

/// Fachada de datos SaaS (Firestore). Mantiene la API usada por las pantallas.
class DBService {
  static final DBService instance = DBService._();
  DBService._();

  final _cloud = CloudCotizacionRepository.instance;

  Future<void> get database async {}

  Future<void> insertarCotizacion(Cotizacion cot) =>
      _cloud.insertarCotizacion(cot);

  Future<List<Cotizacion>> obtenerTodas() => _cloud.obtenerTodas();

  Future<CotizacionPage> obtenerPagina({
    int limit = 20,
    String? startAfterUpdatedAt,
    String? status,
  }) => _cloud.obtenerPagina(
    limit: limit,
    startAfterUpdatedAt: startAfterUpdatedAt,
    status: status,
  );

  Future<void> eliminarCotizacion(String id) => _cloud.eliminarCotizacion(id);

  Future<Quote> duplicateQuote(String id) => _cloud.duplicateQuote(id);

  Future<Quote> createQuoteVersion(String id) => _cloud.createQuoteVersion(id);

  Future<Quote> setQuoteStatus(String id, QuoteStatus status) =>
      _cloud.setQuoteStatus(id, status);

  Future<int> getProximoNumero() => _cloud.getProximoNumero();

  Future<void> incrementarNumero() => _cloud.incrementarNumero();

  Future<void> configurarNumero(int v) => _cloud.configurarNumero(v);

  Future<String> getPrefijo() => _cloud.getPrefijo();

  Future<void> configurarPrefijo(String p) => _cloud.configurarPrefijo(p);
}
