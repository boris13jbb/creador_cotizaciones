import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:creador_cotizaciones/core/utils/money_cents.dart';
import 'package:creador_cotizaciones/l10n/app_localizations.dart';
import 'package:creador_cotizaciones/saas/domain/org_enums.dart';
import 'package:creador_cotizaciones/saas/domain/quote_totals.dart';
import 'package:creador_cotizaciones/saas/models/quote.dart';
import 'package:creador_cotizaciones/saas/providers/auth_controller.dart';
import 'package:creador_cotizaciones/saas/providers/quote_editor_controller.dart';
import 'package:creador_cotizaciones/saas/services/quote_mapper.dart';
import 'package:creador_cotizaciones/screens/quote/quote_branding_section.dart';
import 'package:creador_cotizaciones/services/pdf_service.dart';
import 'package:creador_cotizaciones/theme/app_theme.dart';

Quote _sampleQuote() {
  final now = DateTime.utc(2026, 1, 1);
  return Quote(
    id: 'q1',
    organizationId: 'test-org',
    number: 'BORRADOR',
    sequence: 0,
    clientName: 'Cliente Demo',
    issueDate: now,
    items: [
      QuoteLineItem.fromQuantity(
        id: 'i1',
        name: 'Servicio',
        quantity: 1,
        unitPrice: const MoneyCents(10000),
      ),
    ],
    total: const MoneyCents(10000),
    createdByUid: 'test-uid',
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  testWidgets(
    'QuoteBrandingSection no rompe layout con FilledButton Size.fromHeight',
    (tester) async {
      final controller = QuoteEditorController(
        uid: 'test-uid',
        organizationId: 'test-org',
        resumeDraft: false,
        initialQuote: _sampleQuote(),
      );
      // Espera _init (initializing=false).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ChangeNotifierProvider<AuthController>.value(
            value: AuthController.forTest(authenticated: true),
            child: Scaffold(
              body: ListView(
                children: [QuoteBrandingSection(controller: controller)],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.text('Identidad visual'), findsOneWidget);
      expect(find.textContaining('logotipo'), findsWidgets);
      controller.dispose();
    },
  );

  testWidgets(
    'FilledButton del theme en Row del bottom bar no fuerza ancho infinito',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: const SizedBox.shrink(),
            bottomNavigationBar: Material(
              elevation: 6,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        onPressed: () {},
                        child: const Text('Atrás'),
                      ),
                      const Spacer(),
                      const Flexible(child: Text(r'$100.00')),
                      const SizedBox(width: 12),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        onPressed: () {},
                        child: const Text('Siguiente'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Siguiente'), findsOneWidget);
      expect(find.text('Atrás'), findsOneWidget);
    },
  );

  test('Mapper conserva garantía y términos en campos extra del PDF', () {
    final now = DateTime.utc(2026, 1, 1);
    final quote = Quote(
      id: 'q1',
      organizationId: 'org',
      number: 'COT-1',
      sequence: 1,
      clientName: 'Acme',
      issueDate: now,
      items: const [],
      total: MoneyCents.zero,
      conditions: 'Pago contra entrega',
      createdByUid: 'u1',
      createdAt: now,
      updatedAt: now,
      legacyFields: const {'garantia': '90 días', 'tiempoEstimado': '10 días'},
    );

    final cot = QuoteMapper.toCotizacion(quote);
    expect(cot.tiempoEstimado, '10 días');
    expect(cot.camposExtra, contains('Garantía'));
    expect(cot.camposExtra, contains('90 días'));
    expect(cot.camposExtra, contains('Términos y condiciones'));
    expect(cot.camposExtra, contains('Pago contra entrega'));

    final back = QuoteMapper.fromCotizacion(
      cot,
      organizationId: 'org',
      createdByUid: 'u1',
    );
    expect(back.conditions, 'Pago contra entrega');
    expect(back.legacyFields['garantia'], '90 días');
  });

  test('setPayments y setConditions persisten en el controller', () async {
    final controller = QuoteEditorController(
      uid: 'u1',
      organizationId: 'org1',
      resumeDraft: false,
      initialQuote: _sampleQuote(),
    );
    await Future<void>.delayed(Duration.zero);

    controller.setPayments([
      {
        'label': 'ANTICIPO',
        'description': '50% de entrada',
        'amountCents': 5000,
      },
      {'label': 'SALDO', 'description': '50% saldo', 'amountCents': 5000},
    ]);
    controller.setConditions('Condiciones de prueba');
    controller.setLegacyField('garantia', '1 año');
    controller.setLegacyField('tiempoEstimado', '7 días');
    controller.goTo(2);

    expect(controller.step, 2);
    expect(controller.quote.payments, hasLength(2));
    expect(controller.quote.conditions, 'Condiciones de prueba');
    expect(controller.quote.legacyFields['garantia'], '1 año');
    expect(controller.quote.legacyFields['tiempoEstimado'], '7 días');
    expect(controller.totals.total.cents, 10000);
    controller.dispose();
  });

  test(
    'setPaymentPercents suma exactamente el total y permite limpiar conditions',
    () async {
      final now = DateTime.utc(2026, 1, 1);
      final controller = QuoteEditorController(
        uid: 'u1',
        organizationId: 'org1',
        resumeDraft: false,
        initialQuote: Quote(
          id: 'q1',
          organizationId: 'org1',
          number: 'BORRADOR',
          sequence: 0,
          clientName: 'Cliente',
          issueDate: now,
          items: [
            QuoteLineItem.fromQuantity(
              id: 'i1',
              name: 'Servicio',
              quantity: 1,
              unitPrice: const MoneyCents(10001),
            ),
          ],
          total: const MoneyCents(10001),
          conditions: 'temporal',
          createdByUid: 'u1',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      controller.setPaymentPercents(anticipoPct: 50, saldoPct: 50);
      final sum = controller.quote.payments.fold<int>(
        0,
        (a, p) => a + ((p['amountCents'] as num?)?.round() ?? 0),
      );
      expect(sum, controller.totals.total.cents);
      expect(
        controller.quote.payments.any((p) => p['label'] == 'ENTREGA'),
        isFalse,
      );

      controller.setGlobalDiscountBps(1000); // 10%
      controller.setPaymentPercents(anticipoPct: 40, saldoPct: 40);
      final sum2 = controller.quote.payments.fold<int>(
        0,
        (a, p) => a + ((p['amountCents'] as num?)?.round() ?? 0),
      );
      expect(sum2, controller.totals.total.cents);

      controller.setConditions('');
      expect(controller.quote.conditions, isNull);

      final cot = QuoteMapper.toCotizacion(
        controller.quote.copyWith(
          conditions: 'Término A',
          legacyFields: {
            ...controller.quote.legacyFields,
            'garantia': 'Garantía B',
          },
        ),
      );
      expect(cot.camposExtraList.map((e) => e.key), contains('Garantía'));
      expect(
        cot.camposExtraList.map((e) => e.key),
        contains('Términos y condiciones'),
      );

      controller.dispose();
    },
  );

  test('modalidad un solo pago asigna 100% y saldo 0', () async {
    final controller = QuoteEditorController(
      uid: 'u1',
      organizationId: 'org1',
      resumeDraft: false,
      initialQuote: _sampleQuote(),
    );
    await Future<void>.delayed(Duration.zero);
    final totalBefore = controller.totals.total.cents;

    controller.setPaymentMode(PaymentMode.single);

    expect(controller.quote.paymentMode, PaymentMode.single);
    expect(controller.quote.payments, hasLength(1));
    expect(controller.quote.payments.first['label'], 'UN SOLO PAGO');
    expect(controller.quote.payments.first['amountCents'], totalBefore);
    expect(controller.totals.total.cents, totalBefore);

    final pending =
        totalBefore -
        ((controller.quote.payments.first['amountCents'] as num?)?.round() ??
            0);
    expect(pending, 0);

    final cot = QuoteMapper.toCotizacion(controller.quote);
    expect(cot.formaPago, hasLength(1));
    expect(cot.formaPago.first.etiqueta, 'UN SOLO PAGO');
    expect(cot.formaPago.first.monto, closeTo(totalBefore / 100.0, 0.001));

    controller.dispose();
  });

  test('un solo pago se actualiza al cambiar descuentos/cargos', () async {
    final controller = QuoteEditorController(
      uid: 'u1',
      organizationId: 'org1',
      resumeDraft: false,
      initialQuote: _sampleQuote(),
    );
    await Future<void>.delayed(Duration.zero);

    controller.setPaymentMode(PaymentMode.single);
    controller.setGlobalDiscountBps(1000);
    expect(
      controller.quote.payments.single['amountCents'],
      controller.totals.total.cents,
    );

    controller.setCharges(const MoneyCents(2500));
    expect(
      controller.quote.payments.single['amountCents'],
      controller.totals.total.cents,
    );
    expect(controller.quote.paymentMode, PaymentMode.single);

    controller.dispose();
  });

  test('cambio entre modalidades y persistencia en mapa', () async {
    final controller = QuoteEditorController(
      uid: 'u1',
      organizationId: 'org1',
      resumeDraft: false,
      initialQuote: _sampleQuote(),
    );
    await Future<void>.delayed(Duration.zero);

    controller.setPaymentPercents(anticipoPct: 40, saldoPct: 60);
    expect(controller.quote.paymentMode, PaymentMode.split);
    expect(controller.quote.payments, hasLength(2));

    controller.setPaymentMode(PaymentMode.single);
    expect(controller.quote.payments.single['label'], 'UN SOLO PAGO');

    controller.setPaymentMode(PaymentMode.split);
    expect(controller.quote.paymentMode, PaymentMode.split);
    expect(
      controller.quote.payments.any((p) => p['label'] == 'ANTICIPO'),
      isTrue,
    );
    expect(controller.quote.payments.any((p) => p['label'] == 'SALDO'), isTrue);
    final sum = controller.quote.payments.fold<int>(
      0,
      (a, p) => a + ((p['amountCents'] as num?)?.round() ?? 0),
    );
    expect(sum, controller.totals.total.cents);

    final map = controller.quote.toMap();
    final back = Quote.fromMap(map);
    expect(back.paymentMode, PaymentMode.split);
    expect(back.legacyFields['anticipoPct'], 40);
    expect(back.legacyFields['saldoPct'], 60);

    controller.dispose();
  });

  test('cotización antigua sin paymentMode sigue en anticipo/saldo', () {
    final map = _sampleQuote().toMap()..remove('paymentMode');
    final legacy = Quote.fromMap(map);
    expect(legacy.paymentMode, PaymentMode.split);

    final bytes = QuoteMapper.toCotizacion(
      legacy.copyWith(
        payments: [
          {'label': 'ANTICIPO', 'description': '50%', 'amountCents': 5000},
          {'label': 'SALDO', 'description': '50%', 'amountCents': 5000},
        ],
      ),
    );
    expect(bytes.formaPago.map((e) => e.etiqueta), ['ANTICIPO', 'SALDO']);
  });

  test('PDF un solo pago y anticipo/saldo generan documento válido', () async {
    final single = _sampleQuote().copyWith(
      paymentMode: PaymentMode.single,
      payments: QuoteEditorController.buildSinglePayment(
        const MoneyCents(10000),
      ),
    );
    final split = _sampleQuote().copyWith(
      paymentMode: PaymentMode.split,
      payments: QuoteEditorController.buildSplitPayments(
        total: const MoneyCents(10000),
        anticipoPct: 50,
        saldoPct: 50,
      ),
    );

    final pdfSingle = await PdfService.generarPDFFromQuote(single);
    final pdfSplit = await PdfService.generarPDFFromQuote(split);
    expect(String.fromCharCodes(pdfSingle.take(5)), '%PDF-');
    expect(String.fromCharCodes(pdfSplit.take(5)), '%PDF-');
    expect(single.total.cents, 10000);
    expect(split.total.cents, 10000);
  });
}
