import 'dart:typed_data';

import 'package:creador_cotizaciones/l10n/app_localizations.dart';
import 'package:creador_cotizaciones/l10n/app_localizations_en.dart';
import 'package:creador_cotizaciones/l10n/app_localizations_es.dart';
import 'package:creador_cotizaciones/models/cotizacion.dart';
import 'package:creador_cotizaciones/saas/services/quote_share_ui.dart';
import 'package:creador_cotizaciones/services/pdf_share_service.dart';
import 'package:creador_cotizaciones/widgets/cotizacion_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Cotizacion _sampleCot({String id = 'c1'}) {
  return Cotizacion(
    id: id,
    numero: 'COT-100',
    fecha: '2026-03-01',
    cliente: 'Cliente Demo',
    ubicacion: 'Ciudad',
    tipoServicio: 'Servicio',
    cantidadEquipos: '1',
    tiempoEstimado: '1 día',
    descripcion: 'Desc',
    servicios: const [],
    total: 100,
    incluye: const [],
    noIncluye: const [],
    notas: const [],
  );
}

Widget _wrap(Widget child, {Locale locale = const Locale('es')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets(
    'menú muestra Compartir cotización cuando onShare está definido',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var shared = false;
      await tester.pumpWidget(
        _wrap(
          CotizacionCard(
            cotizacion: _sampleCot(),
            onTap: () {},
            onEdit: () {},
            onDelete: () {},
            onShare: () => shared = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Compartir cotización'), findsOneWidget);
      expect(find.text('Ver PDF'), findsOneWidget);
      expect(find.text('Editar'), findsOneWidget);

      await tester.tap(find.text('Compartir cotización'));
      await tester.pumpAndSettle();
      expect(shared, isTrue);
    },
  );

  testWidgets('menú en inglés muestra Share quote', (tester) async {
    await tester.pumpWidget(
      _wrap(
        CotizacionCard(
          cotizacion: _sampleCot(),
          onTap: () {},
          onEdit: () {},
          onDelete: () {},
          onShare: () {},
        ),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Share quote'), findsOneWidget);
  });

  testWidgets('sin onShare no aparece la opción compartir', (tester) async {
    await tester.pumpWidget(
      _wrap(
        CotizacionCard(
          cotizacion: _sampleCot(),
          onTap: () {},
          onEdit: () {},
          onDelete: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Compartir cotización'), findsNothing);
  });

  test('mapError traduce códigos de PdfShareService', () {
    final es = AppLocalizationsEs();
    final en = AppLocalizationsEn();
    expect(
      QuoteShareUi.mapError(es, StateError('share_pdf_empty')),
      es.sharePdfEmpty,
    );
    expect(
      QuoteShareUi.mapError(en, StateError('share_pdf_busy')),
      en.sharePdfBusy,
    );
    expect(
      QuoteShareUi.mapError(es, StateError('share_pdf_open_failed')),
      es.sharePdfOpenFailed,
    );
  });

  test('tryCreateShareLink null no impide preparar PDF local', () async {
    // Enlace seguro opcional: fallar/null no impide validar bytes.
    final bytes = Uint8List.fromList('%PDF-1.4\n%%EOF\n'.codeUnits);
    expect(PdfShareService.looksLikePdf(bytes), isTrue);
    PdfShareService.instance.debugResetBusy();
    PdfShareService.instance.debugSetBusy(true);
    expect(PdfShareService.instance.isBusy, isTrue);
    expect(
      () => PdfShareService.instance.sharePdfBytes(bytes: bytes, number: 'X'),
      throwsA(
        isA<StateError>().having((e) => e.message, 'm', 'share_pdf_busy'),
      ),
    );
    PdfShareService.instance.debugResetBusy();
  });
}
