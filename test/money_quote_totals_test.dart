import 'package:flutter_test/flutter_test.dart';
import 'package:creador_cotizaciones/core/utils/money_cents.dart';
import 'package:creador_cotizaciones/saas/domain/quote_totals.dart';

void main() {
  group('MoneyCents', () {
    test('fromDecimal redondea half-up', () {
      expect(MoneyCents.fromDecimal(10.5).cents, 1050);
      expect(MoneyCents.fromDecimal(10.004).cents, 1000);
      expect(MoneyCents.fromDecimal(-10.5).cents, -1050);
    });

    test('percentBps calcula descuentos', () {
      final base = MoneyCents(10000); // $100.00
      expect(base.percentBps(1000).cents, 1000); // 10%
      expect(base.percentBps(50).cents, 50); // 0.5%
    });

    test('suma y resta exactas', () {
      expect((MoneyCents(199) + MoneyCents(1)).cents, 200);
      expect((MoneyCents(200) - MoneyCents(50)).cents, 150);
    });
  });

  group('QuoteTotalsCalculator', () {
    const calc = QuoteTotalsCalculator();

    test('línea con cantidad fraccionaria y descuento/impuesto', () {
      final item = QuoteLineItem.fromQuantity(
        id: '1',
        name: 'Servicio',
        quantity: 2.5,
        unitPrice: const MoneyCents(1000), // $10
        discountBps: 1000, // 10%
        taxBps: 1200, // 12%
      );
      // gross = 10 * 2.5 = 25.00 → 2500
      // disc 10% = 250
      // after = 2250
      // tax 12% = 270
      // net = 2520
      final line = calc.lineAmounts(item);
      expect(line.gross.cents, 2500);
      expect(line.discount.cents, 250);
      expect(line.tax.cents, 270);
      expect(line.net.cents, 2520);
    });

    test('total con descuento global y cargos', () {
      final items = [
        QuoteLineItem.fromQuantity(
          id: 'a',
          name: 'A',
          quantity: 1,
          unitPrice: const MoneyCents(10000),
        ),
        QuoteLineItem.fromQuantity(
          id: 'b',
          name: 'B',
          quantity: 1,
          unitPrice: const MoneyCents(5000),
        ),
      ];
      final totals = calc.calculate(
        items: items,
        globalDiscountBps: 1000, // 10% de 15000 = 1500
        charges: const MoneyCents(200),
      );
      expect(totals.linesNet.cents, 15000);
      expect(totals.globalDiscount.cents, 1500);
      expect(totals.total.cents, 13700); // 15000 - 1500 + 200
    });

    test('descuento global no deja total negativo', () {
      final items = [
        QuoteLineItem.fromQuantity(
          id: 'a',
          name: 'A',
          quantity: 1,
          unitPrice: const MoneyCents(100),
        ),
      ];
      final totals = calc.calculate(
        items: items,
        globalDiscountFixed: const MoneyCents(500),
      );
      expect(totals.total.cents, 0);
    });
  });
}
