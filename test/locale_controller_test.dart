import 'package:creador_cotizaciones/l10n/app_localizations.dart';
import 'package:creador_cotizaciones/l10n/app_localizations_en.dart';
import 'package:creador_cotizaciones/l10n/app_localizations_es.dart';
import 'package:creador_cotizaciones/saas/domain/org_enums.dart';
import 'package:creador_cotizaciones/saas/historial/historial_query.dart';
import 'package:creador_cotizaciones/ui/providers/locale_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('sin preferencia usa español', () async {
    final ctrl = LocaleController();
    await ctrl.load();
    expect(ctrl.locale, const Locale('es'));
    expect(ctrl.isSpanish, isTrue);
  });

  test('persiste inglés y lo recupera', () async {
    final ctrl = LocaleController();
    await ctrl.load();
    await ctrl.setLanguageCode('en');
    expect(ctrl.isEnglish, isTrue);

    final again = LocaleController();
    await again.load();
    expect(again.locale, const Locale('en'));
  });

  test('código inválido cae a español', () async {
    SharedPreferences.setMockInitialValues({LocaleController.prefsKey: 'fr'});
    final ctrl = LocaleController();
    await ctrl.load();
    expect(ctrl.locale, const Locale('es'));
  });

  test('cambio de locale notifica sin tocar sesión', () async {
    final ctrl = LocaleController();
    await ctrl.load();
    var notified = 0;
    ctrl.addListener(() => notified++);
    await ctrl.setLocale(const Locale('en'));
    expect(notified, 1);
    await ctrl.setLocale(const Locale('en'));
    expect(notified, 1);
  });

  test('etiquetas de estado Historial difieren es/en', () {
    final es = AppLocalizationsEs();
    final en = AppLocalizationsEn();
    expect(HistorialQuery.statusLabel(QuoteStatus.draft, es), 'Borrador');
    expect(HistorialQuery.statusLabel(QuoteStatus.draft, en), 'Draft');
    expect(HistorialQuery.statusLabel(QuoteStatus.archived, en), 'Archived');
  });

  test('AppLocalizations supportedLocales incluye es y en', () {
    expect(
      AppLocalizations.supportedLocales.map((e) => e.languageCode),
      containsAll(['es', 'en']),
    );
  });

  testWidgets('MaterialApp refleja locale del controlador', (tester) async {
    final ctrl = LocaleController();
    await ctrl.load();
    await tester.pumpWidget(
      AnimatedBuilder(
        animation: ctrl,
        builder: (context, _) {
          return MaterialApp(
            locale: ctrl.locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                final l10n = AppLocalizations.of(context);
                return Text(l10n.navHistory);
              },
            ),
          );
        },
      ),
    );
    expect(find.text('Historial'), findsOneWidget);
    await ctrl.setLanguageCode('en');
    await tester.pumpAndSettle();
    expect(find.text('History'), findsOneWidget);
  });
}
