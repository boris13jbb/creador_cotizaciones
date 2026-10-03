import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:creador_cotizaciones/main.dart';
import 'package:creador_cotizaciones/saas/providers/auth_controller.dart';
import 'package:creador_cotizaciones/saas/services/cloud_cotizacion_repository.dart';
import 'package:creador_cotizaciones/screens/auth/auth_gate.dart';
import 'package:creador_cotizaciones/ui/layout/app_shell.dart';
import 'package:creador_cotizaciones/ui/providers/theme_controller.dart';

Widget _buildTestApp(AuthController auth) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthController>.value(value: auth),
      ChangeNotifierProvider(create: (_) => ThemeController()),
    ],
    child: const CotiApp(),
  );
}

void main() {
  setUp(() {
    CloudCotizacionRepository.useEmptyStoreForTests = true;
  });

  tearDown(() {
    CloudCotizacionRepository.useEmptyStoreForTests = false;
  });

  testWidgets('arranque muestra marca CotiApp y pantalla de login', (
    WidgetTester tester,
  ) async {
    final auth = AuthController.forTest();
    await tester.pumpWidget(_buildTestApp(auth));
    await tester.pumpAndSettle();

    expect(find.byType(AuthGate), findsOneWidget);
    expect(find.text('CotiApp'), findsWidgets);
    expect(find.text('Bienvenido'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets('login valida correo y contraseña vacíos', (
    WidgetTester tester,
  ) async {
    final auth = AuthController.forTest();
    await tester.pumpWidget(_buildTestApp(auth));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Ingresa tu correo'), findsOneWidget);
    expect(find.text('Ingresa tu contraseña'), findsOneWidget);
  });

  testWidgets('navegación básica a crear cuenta', (WidgetTester tester) async {
    final auth = AuthController.forTest();
    await tester.pumpWidget(_buildTestApp(auth));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();

    expect(find.text('Crear cuenta'), findsWidgets);
    expect(find.textContaining('14 días'), findsOneWidget);
  });

  testWidgets('sesión autenticada muestra inicio CotiApp', (
    WidgetTester tester,
  ) async {
    final auth = AuthController.forTest(authenticated: true);
    CloudCotizacionRepository.instance.bindAuth(auth);

    await tester.pumpWidget(_buildTestApp(auth));
    await tester.pumpAndSettle();

    expect(find.byType(AppShell), findsOneWidget);
    expect(find.text('CotiApp'), findsWidgets);
    expect(find.text('¿Qué deseas crear hoy?'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsNothing);
    expect(find.text('Inicio'), findsOneWidget);
  });
}
