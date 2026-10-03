import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:creador_cotizaciones/saas/providers/auth_controller.dart';
import 'package:creador_cotizaciones/saas/services/cloud_cotizacion_repository.dart';
import 'package:creador_cotizaciones/theme/app_theme.dart';
import 'package:creador_cotizaciones/ui/layout/app_shell.dart';
import 'package:creador_cotizaciones/ui/providers/theme_controller.dart';
import 'package:creador_cotizaciones/ui/widgets/async_state_view.dart';
import 'package:creador_cotizaciones/screens/auth/auth_scaffold.dart';

void main() {
  setUp(() {
    CloudCotizacionRepository.useEmptyStoreForTests = true;
  });

  tearDown(() {
    CloudCotizacionRepository.useEmptyStoreForTests = false;
  });

  Future<void> pumpAtSize(
    WidgetTester tester, {
    required Size size,
    required Widget child,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final auth = AuthController.forTest(authenticated: true);
    CloudCotizacionRepository.instance.bindAuth(auth);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider(create: (_) => ThemeController()),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          home: child,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('AppShell sin overflow a 320px', (tester) async {
    await pumpAtSize(
      tester,
      size: const Size(320, 640),
      child: const AppShell(),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('¿Qué deseas crear hoy?'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('AppShell usa NavigationRail en escritorio', (tester) async {
    await pumpAtSize(
      tester,
      size: const Size(1280, 800),
      child: const AppShell(),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('AuthScaffold sin overflow a 320px', (tester) async {
    await pumpAtSize(
      tester,
      size: const Size(320, 568),
      child: AuthScaffold(
        title: 'Bienvenido',
        subtitle: 'Prueba layout',
        child: Column(
          children: [
            const TextField(decoration: InputDecoration(labelText: 'Correo')),
            const SizedBox(height: 12),
            FilledButton(onPressed: () {}, child: const Text('Entrar')),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('CotiApp'), findsOneWidget);
  });

  testWidgets('AsyncStateView muestra offline y reintento', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AsyncStateView(
            error: Exception('SocketException: failed host lookup'),
            onRetry: () => retried = true,
            child: const Text('ok'),
          ),
        ),
      ),
    );
    expect(find.text('Sin conexión'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    expect(retried, isTrue);
  });
}
