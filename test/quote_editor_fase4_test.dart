import 'package:flutter_test/flutter_test.dart';
import 'package:creador_cotizaciones/core/utils/money_cents.dart';
import 'package:creador_cotizaciones/models/cotizacion.dart';
import 'package:creador_cotizaciones/models/servicio.dart';
import 'package:creador_cotizaciones/saas/domain/org_enums.dart';
import 'package:creador_cotizaciones/saas/domain/quote_totals.dart';
import 'package:creador_cotizaciones/saas/models/quote.dart';
import 'package:creador_cotizaciones/saas/providers/quote_editor_controller.dart';
import 'package:creador_cotizaciones/saas/services/quote_mapper.dart';

void main() {
  test('QuoteMapper conserva neto de línea con descuento e impuesto', () {
    final quote = Quote(
      id: 'q1',
      organizationId: 'org',
      number: 'COT-001',
      sequence: 1,
      clientName: 'Acme',
      issueDate: DateTime.utc(2026, 1, 1),
      items: [
        QuoteLineItem.fromQuantity(
          id: 'l1',
          name: 'Servicio',
          quantity: 2,
          unitPrice: const MoneyCents(10000),
          discountBps: 1000,
          taxBps: 1000,
        ),
      ],
      total: MoneyCents.zero,
      createdByUid: 'u1',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    ).withRecalculatedTotal();

    final cot = QuoteMapper.toCotizacion(quote);
    expect(cot.servicios, hasLength(1));
    // 2*100 = 200; -10% = 180; +10% = 198
    expect(cot.servicios.first.precio, closeTo(198.0, 0.01));
    expect(cot.total, closeTo(198.0, 0.01));
  });

  test('QuoteEditorController valida pasos de cliente e ítems', () async {
    final controller = QuoteEditorController(
      uid: 'u1',
      organizationId: 'org1',
      resumeDraft: false,
      initialQuote: Quote(
        id: 'q1',
        organizationId: 'org1',
        number: 'BORRADOR',
        sequence: 0,
        clientName: '',
        issueDate: DateTime.now().toUtc(),
        items: const [],
        total: MoneyCents.zero,
        createdByUid: 'u1',
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(controller.validateStep(0), isNotNull);
    controller.setClientName('Cliente');
    expect(controller.validateStep(0), isNull);
    expect(controller.validateStep(1), isNotNull);
    controller.upsertItem(
      QuoteLineItem.fromQuantity(
        id: 'i1',
        name: 'Item',
        quantity: 1,
        unitPrice: const MoneyCents(500),
      ),
    );
    expect(controller.validateStep(1), isNull);
    expect(controller.totals.total.cents, 500);
    controller.dispose();
  });

  test('fromCotizacion legacy crea líneas qty=1', () {
    final cot = Cotizacion(
      id: 'c1',
      numero: 'COT-1',
      fecha: '2026-01-01',
      cliente: 'X',
      ubicacion: 'Y',
      tipoServicio: 'Z',
      cantidadEquipos: '1',
      tiempoEstimado: '1h',
      descripcion: 'd',
      servicios: [Servicio(nombre: 'A', descripcion: '', precio: 50)],
      total: 50,
      incluye: const [],
      noIncluye: const [],
      notas: const [],
    );
    final quote = QuoteMapper.fromCotizacion(
      cot,
      organizationId: 'org',
      createdByUid: 'u',
      status: QuoteStatus.draft,
    );
    expect(quote.items.single.quantity, 1);
    expect(quote.items.single.unitPrice.cents, 5000);
  });
}
