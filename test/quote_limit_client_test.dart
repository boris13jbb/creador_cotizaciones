import 'package:creador_cotizaciones/saas/services/quote_create_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('isLimitExceededError detecta resource-exhausted y mensaje Free', () {
    expect(
      QuoteCreateService.isLimitExceededError(
        QuoteLimitExceededException(
          'Límite del plan Free: máximo 5 cotizaciones. Actualiza a Pro para continuar.',
        ),
      ),
      isTrue,
    );
    expect(
      QuoteCreateService.isLimitExceededError(
        Exception('resource-exhausted'),
      ),
      isTrue,
    );
    expect(
      QuoteCreateService.isLimitExceededError(Exception('timeout de red')),
      isFalse,
    );
  });

  test('QuoteLimitExceededException expone mensaje al usuario', () {
    const msg = 'Límite del plan Free: máximo 5 cotizaciones.';
    final err = QuoteLimitExceededException(msg);
    expect(err.toString(), msg);
  });
}
