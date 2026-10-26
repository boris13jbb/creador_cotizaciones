import 'package:creador_cotizaciones/saas/services/auth_service.dart';
import 'package:creador_cotizaciones/saas/services/quote_create_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthEmailStatus', () {
    test('emailsMatch ignora mayúsculas y espacios', () {
      expect(
        AuthEmailStatus.emailsMatch(
          '  Bucar13JB@gmail.com ',
          'bucar13jb@gmail.com',
        ),
        isTrue,
      );
    });

    test('emailsMatch detecta discrepancia', () {
      expect(
        AuthEmailStatus.emailsMatch('a@example.com', 'b@example.com'),
        isFalse,
      );
    });

    test('emailsMatch tolera vacío (sin falso positivo de mismatch)', () {
      expect(AuthEmailStatus.emailsMatch('', 'a@example.com'), isTrue);
      expect(AuthEmailStatus.emailsMatch(null, null), isTrue);
    });

    test('ok requiere sesión sin errorCode', () {
      const good = AuthEmailStatus(
        hasSession: true,
        email: 'a@example.com',
        emailVerified: true,
      );
      expect(good.ok, isTrue);
      expect(good.emailVerified, isTrue);

      const badNet = AuthEmailStatus(
        hasSession: true,
        email: 'a@example.com',
        emailVerified: false,
        errorCode: 'unavailable',
        errorMessage: 'Sin conexión a internet.',
      );
      expect(badNet.ok, isFalse);
      expect(badNet.emailVerified, isFalse);
    });

    test('cuenta no verificada no se marca como verificada', () {
      const pending = AuthEmailStatus(
        hasSession: true,
        email: 'bucar13jb@gmail.com',
        emailVerified: false,
      );
      expect(pending.emailVerified, isFalse);
      expect(pending.ok, isTrue);
    });
  });

  group('errores sync preservados', () {
    test('mapFunctionsError conserva app/no-app vía mensaje internal', () {
      final err = QuoteCreateService.mapFunctionsError(
        'internal',
        'No se pudo crear la cotización (app/no-app)',
      );
      expect(err, isA<QuoteCreateException>());
      final q = err as QuoteCreateException;
      expect(q.code, 'internal');
      expect(q.message, contains('app/no-app'));
    });
  });
}
