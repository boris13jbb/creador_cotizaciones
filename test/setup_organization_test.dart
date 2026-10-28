import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:creador_cotizaciones/l10n/app_localizations.dart';
import 'package:creador_cotizaciones/saas/providers/auth_controller.dart';
import 'package:creador_cotizaciones/screens/auth/setup_organization_screen.dart';
import 'package:creador_cotizaciones/ui/providers/locale_controller.dart';
import 'package:creador_cotizaciones/ui/providers/theme_controller.dart';

Widget _wrap(AuthController auth) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthController>.value(value: auth),
      ChangeNotifierProvider(create: (_) => ThemeController()),
      ChangeNotifierProvider(create: (_) => LocaleController()),
    ],
    child: MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SetupOrganizationScreen(),
    ),
  );
}

void main() {
  testWidgets('setup organización pide nombre y CTA Continuar', (tester) async {
    final auth = AuthController.forTest(
      authenticated: true,
      withOrganization: false,
    );

    await tester.pumpWidget(_wrap(auth));
    await tester.pumpAndSettle();

    expect(find.text('Crea tu organización'), findsOneWidget);
    expect(find.text('Continuar'), findsOneWidget);
    expect(find.text('Cerrar sesión'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
  });

  testWidgets('AuthGate autenticado sin org muestra setup', (tester) async {
    final auth = AuthController.forTest(
      authenticated: true,
      withOrganization: false,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthController>.value(value: auth),
          ChangeNotifierProvider(create: (_) => ThemeController()),
          ChangeNotifierProvider(create: (_) => LocaleController()),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              if (auth.needsOrganizationSetup) {
                return const SetupOrganizationScreen();
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(auth.needsOrganizationSetup, isTrue);
    expect(find.text('Crea tu organización'), findsOneWidget);
  });
}
