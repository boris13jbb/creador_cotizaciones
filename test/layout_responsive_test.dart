import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:creador_cotizaciones/saas/offline/offline_controller.dart';
import 'package:creador_cotizaciones/saas/providers/auth_controller.dart';
import 'package:creador_cotizaciones/saas/services/cloud_cotizacion_repository.dart';
import 'package:creador_cotizaciones/theme/app_theme.dart';
import 'package:creador_cotizaciones/l10n/app_localizations.dart';
import 'package:creador_cotizaciones/ui/layout/app_shell.dart';
import 'package:creador_cotizaciones/ui/layout/responsive.dart';
import 'package:creador_cotizaciones/ui/providers/locale_controller.dart';
import 'package:creador_cotizaciones/ui/providers/theme_controller.dart';
import 'package:creador_cotizaciones/ui/widgets/async_state_view.dart';
import 'package:creador_cotizaciones/ui/widgets/app_action_tile.dart';
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
          ChangeNotifierProvider<AuthController>.value(value: auth),
          ChangeNotifierProvider<OfflineController>.value(
            value: OfflineController.instance,
          ),
          ChangeNotifierProvider(create: (_) => ThemeController()),
          ChangeNotifierProvider(create: (_) => LocaleController()),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          locale: const Locale('es'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: child,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Breakpoints', () {
    testWidgets('compact / medium / expanded según ancho', (tester) async {
      late AppWindowSize compact;
      late AppWindowSize medium;
      late AppWindowSize expanded;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              compact = Responsive.windowSizeOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              compact = Responsive.windowSizeOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(compact, AppWindowSize.compact);

      tester.view.physicalSize = const Size(768, 1024);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              medium = Responsive.windowSizeOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(medium, AppWindowSize.medium);

      tester.view.physicalSize = const Size(1440, 900);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              expanded = Responsive.windowSizeOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(expanded, AppWindowSize.expanded);

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    testWidgets('nativo usa rail desde 840px', (tester) async {
      var useRail = false;
      tester.view.physicalSize = const Size(900, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              useRail = Responsive.useNavigationRail(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      // En tests (no Web) el umbral nativo es 840.
      expect(useRail, isTrue);
      expect(Responsive.isWebAdaptive, isFalse);
    });
  });

  testWidgets('AppShell sin overflow a 360x800', (tester) async {
    await pumpAtSize(
      tester,
      size: const Size(360, 800),
      child: const AppShell(),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('¿Qué deseas crear hoy?'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

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

  testWidgets('AppShell usa NavigationRail en escritorio 1440', (tester) async {
    await pumpAtSize(
      tester,
      size: const Size(1440, 900),
      child: const AppShell(),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('AppShell tablet nativo 768 usa NavigationBar', (tester) async {
    await pumpAtSize(
      tester,
      size: const Size(768, 1024),
      child: const AppShell(),
    );
    expect(tester.takeException(), isNull);
    // Sin kIsWeb: drawer web no aplica; < nativeRail (840) → bottom bar.
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationDrawer), findsNothing);
  });

  testWidgets('AppShell conserva destinos al cambiar pestaña', (tester) async {
    await pumpAtSize(
      tester,
      size: const Size(390, 844),
      child: const AppShell(),
    );
    final bar = find.byType(NavigationBar);
    expect(bar, findsOneWidget);

    // Invoca el callback del NavigationBar (evita taps ambiguos por iconos
    // compartidos con estados vacíos).
    tester.widget<NavigationBar>(bar).onDestinationSelected!(
      AppDestination.historial.index,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.widget<NavigationBar>(bar).selectedIndex,
      AppDestination.historial.index,
    );

    tester.widget<NavigationBar>(bar).onDestinationSelected!(
      AppDestination.reports.index,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.widget<NavigationBar>(bar).selectedIndex,
      AppDestination.reports.index,
    );
  });

  testWidgets('AppActionGrid 1 columna bajo 360px', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppActionGrid(
            children: [
              AppActionTile(
                title: 'A',
                subtitle: 'uno',
                icon: Icons.add,
                onTap: () {},
              ),
              AppActionTile(
                title: 'B',
                subtitle: 'dos',
                icon: Icons.history,
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
  });

  testWidgets('AdaptiveAlertDialog cabe en viewport estrecho', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (ctx) => AdaptiveAlertDialog(
                      title: const Text('Diálogo'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          12,
                          (i) => TextField(
                            decoration: InputDecoration(labelText: 'Campo $i'),
                          ),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cerrar'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Diálogo'), findsOneWidget);
    expect(tester.takeException(), isNull);
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

  testWidgets('ResponsiveGrid KPI no desborda a 360', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: ResponsiveGrid(
              columns: 2,
              children: List.generate(
                6,
                (i) => Container(
                  color: Colors.green.shade100,
                  padding: const EdgeInsets.all(8),
                  child: Text('KPI $i · valor muy largo para ellipsis'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
