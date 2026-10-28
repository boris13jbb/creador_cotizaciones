import 'package:creador_cotizaciones/core/utils/money_cents.dart';
import 'package:creador_cotizaciones/saas/domain/org_enums.dart';
import 'package:creador_cotizaciones/saas/domain/quote_totals.dart';
import 'package:creador_cotizaciones/saas/models/quote.dart';
import 'package:creador_cotizaciones/services/pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PDF embebe Noto Sans y admite texto con tildes', () async {
    final now = DateTime.utc(2026, 10, 25);
    final quote = Quote(
      id: 'q-unicode',
      organizationId: 'org-unicode',
      number: 'COT-01',
      sequence: 1,
      status: QuoteStatus.draft,
      clientName: 'Compañía Técnica Andalucía',
      issueDate: now,
      items: [
        QuoteLineItem.fromQuantity(
          id: 'l1',
          name: 'Revisión eléctrica',
          description: 'Instalación y configuración',
          quantity: 1,
          unitPrice: const MoneyCents(10000),
        ),
      ],
      total: const MoneyCents(10000),
      createdByUid: 'u1',
      createdAt: now,
      updatedAt: now,
      legacyFields: const {'validezDias': 15},
    );

    final bytes = await PdfService.generarPDFFromQuote(quote);
    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');

    // El subset embebido debe referenciar NotoSans (no Helvetica por defecto).
    final asLatin1 = String.fromCharCodes(bytes);
    expect(asLatin1.contains('NotoSans'), isTrue);
  });
}
