import 'package:creador_cotizaciones/saas/services/quote_create_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Documenta el contrato de errores del P0 (cupo + mensajes).
/// El rechazo sin org se cubre en reglas + rutas de repositorio (AuthGate).
void main() {
  test('mensajes de cupo Free son detectables por sync offline', () {
    final msg =
        'Límite del plan Free: máximo 5 cotizaciones. Actualiza a Pro para continuar.';
    expect(QuoteCreateService.isLimitExceededError(Exception(msg)), isTrue);
    expect(
      QuoteCreateService.isLimitExceededError(
        QuoteLimitExceededException(msg),
      ),
      isTrue,
    );
  });
}
