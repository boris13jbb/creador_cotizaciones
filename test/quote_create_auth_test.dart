import 'package:creador_cotizaciones/saas/services/auth_service.dart';
import 'package:creador_cotizaciones/saas/services/quote_create_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QuoteCreateService.mapFunctionsError', () {
    test('preserva unauthenticated con mensaje seguro', () {
      final err = QuoteCreateService.mapFunctionsError(
        'unauthenticated',
        'Debes iniciar sesión',
      );
      expect(err, isA<QuoteCreateException>());
      final q = err as QuoteCreateException;
      expect(q.code, 'unauthenticated');
      expect(q.isUnauthenticated, isTrue);
      expect(q.message, contains('iniciar sesión'));
      expect(q.toString(), contains('unauthenticated'));
    });

    test('normaliza UNAUTHENTICATED y functions/ prefix', () {
      final a =
          QuoteCreateService.mapFunctionsError('UNAUTHENTICATED', null)
              as QuoteCreateException;
      expect(a.code, 'unauthenticated');

      final b =
          QuoteCreateService.mapFunctionsError(
                'functions/permission-denied',
                'No eres miembro',
              )
              as QuoteCreateException;
      expect(b.code, 'permission-denied');
      expect(b.message, 'No eres miembro');
    });

    test('resource-exhausted → QuoteLimitExceededException', () {
      final err = QuoteCreateService.mapFunctionsError(
        'resource-exhausted',
        'Límite del plan Free: máximo 5 cotizaciones.',
      );
      expect(err, isA<QuoteLimitExceededException>());
      expect(QuoteCreateService.isLimitExceededError(err), isTrue);
    });

    test('no convierte permission-denied en unauthenticated', () {
      final err =
          QuoteCreateService.mapFunctionsError(
                'permission-denied',
                'Tu rol no puede crear cotizaciones',
              )
              as QuoteCreateException;
      expect(err.code, 'permission-denied');
      expect(err.isUnauthenticated, isFalse);
    });

    test('preserva failed-precondition, unavailable, internal', () {
      for (final code in [
        'failed-precondition',
        'unavailable',
        'deadline-exceeded',
        'internal',
      ]) {
        final err =
            QuoteCreateService.mapFunctionsError(code, 'msg-$code')
                as QuoteCreateException;
        expect(err.code, code);
        expect(err.message, 'msg-$code');
      }
    });

    test('mensaje vacío usa fallback con código, no genérico ciego', () {
      final err =
          QuoteCreateService.mapFunctionsError('internal', null)
              as QuoteCreateException;
      expect(err.code, 'internal');
      expect(err.message, contains('internal'));
    });

    test('no expone bearer/idToken en mensaje de usuario', () {
      final err =
          QuoteCreateService.mapFunctionsError(
                'internal',
                'Authorization: Bearer abc.def.ghi',
              )
              as QuoteCreateException;
      expect(err.message.toLowerCase(), isNot(contains('bearer')));
      expect(err.message.toLowerCase(), isNot(contains('abc.def')));
    });
  });

  group('CallableAuthException', () {
    test('marca unauthenticated', () {
      final e = CallableAuthException(
        code: 'unauthenticated',
        message: 'Debes iniciar sesión para sincronizar.',
      );
      expect(e.isUnauthenticated, isTrue);
      expect(e.toString(), contains('unauthenticated'));
    });
  });

  group('payload / cola', () {
    test('payloadMarksNewQuote sigue intacto para reintento create', () {
      expect(
        QuoteCreateService.payloadMarksNewQuote({'__isNew': true}),
        isTrue,
      );
    });
  });
}
