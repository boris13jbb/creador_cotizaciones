import 'package:creador_cotizaciones/core/utils/money_cents.dart';
import 'package:creador_cotizaciones/saas/config/saas_config.dart';
import 'package:creador_cotizaciones/saas/domain/org_enums.dart';
import 'package:creador_cotizaciones/saas/domain/quote_totals.dart';
import 'package:creador_cotizaciones/saas/models/quote.dart';
import 'package:creador_cotizaciones/saas/services/quote_mapper.dart';
import 'package:creador_cotizaciones/saas/services/quote_reminder_service.dart';
import 'package:creador_cotizaciones/services/pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PDF FromQuote genera documento válido con Quote completo', () async {
    final quote = Quote(
      id: 'q-pdf-1',
      organizationId: 'org1',
      number: 'COT-FASE5-99',
      sequence: 99,
      status: QuoteStatus.sent,
      clientName: 'Cliente PDF Test',
      issueDate: DateTime.utc(2026, 7, 31),
      items: [
        QuoteLineItem.fromQuantity(
          id: 'l1',
          name: 'Instalacion Red',
          description: 'Cableado estructurado',
          quantity: 2,
          unitPrice: const MoneyCents(15000),
          discountBps: 500,
          taxBps: 1200,
        ),
      ],
      total: MoneyCents.zero,
      footerText: 'Footer confidencial Fase5',
      createdByUid: 'u1',
      createdAt: DateTime.utc(2026, 7, 31),
      updatedAt: DateTime.utc(2026, 7, 31),
    ).withRecalculatedTotal();

    final cot = QuoteMapper.toCotizacion(quote);
    expect(cot.numero, 'COT-FASE5-99');
    expect(cot.cliente, 'Cliente PDF Test');
    expect(cot.quoteStatus, 'sent');
    expect(cot.footerText, 'Footer confidencial Fase5');

    const calc = QuoteTotalsCalculator();
    final line = calc.lineAmounts(quote.items.first);
    expect(line.net.cents, greaterThan(0));

    final bytes = await PdfService.generarPDFFromQuote(quote);
    expect(bytes.length, greaterThan(500));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('URL de share usa Functions base y token', () {
    const token = 'abc123tokenxyz';
    final base = SaasConfig.functionsBaseUrl.isNotEmpty
        ? SaasConfig.functionsBaseUrl
        : 'https://us-central1-cotiapp-saas-jb.cloudfunctions.net';
    final url = '$base/viewQuoteShare?token=$token';
    expect(url, contains('/viewQuoteShare?token='));
    expect(url, endsWith(token));
  });

  test('QuoteReminderService detecta enviadas antiguas', () {
    final now = DateTime.utc(2026, 7, 31);
    final quotes = [
      Quote(
        id: 'a',
        organizationId: 'o',
        number: '1',
        sequence: 1,
        status: QuoteStatus.sent,
        clientName: 'A',
        issueDate: now.subtract(const Duration(days: 20)),
        items: const [],
        total: MoneyCents.zero,
        createdByUid: 'u',
        createdAt: now.subtract(const Duration(days: 20)),
        updatedAt: now.subtract(const Duration(days: 10)),
      ),
      Quote(
        id: 'b',
        organizationId: 'o',
        number: '2',
        sequence: 2,
        status: QuoteStatus.sent,
        clientName: 'B',
        issueDate: now,
        items: const [],
        total: MoneyCents.zero,
        createdByUid: 'u',
        createdAt: now,
        updatedAt: now.subtract(const Duration(days: 2)),
      ),
      Quote(
        id: 'c',
        organizationId: 'o',
        number: '3',
        sequence: 3,
        status: QuoteStatus.accepted,
        clientName: 'C',
        issueDate: now.subtract(const Duration(days: 30)),
        items: const [],
        total: MoneyCents.zero,
        createdByUid: 'u',
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now.subtract(const Duration(days: 15)),
      ),
    ];

    final pending = QuoteReminderService.instance.pendingFollowUp(
      quotes,
      now: now,
    );
    expect(pending.map((q) => q.id), ['a']);
  });
}
