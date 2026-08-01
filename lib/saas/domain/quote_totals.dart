import '../../core/utils/money_cents.dart';

/// Línea de cotización con cantidad, precio, descuento e impuesto.
class QuoteLineItem {
  final String id;
  final String? catalogItemId;
  final String code;
  final String name;
  final String description;
  final String unit;

  /// Cantidad en milésimas (1.5 → 1500) para 3 decimales exactos.
  final int quantityMillis;
  final MoneyCents unitPrice;
  final int discountBps;
  final int taxBps;
  final int sortOrder;

  const QuoteLineItem({
    required this.id,
    this.catalogItemId,
    this.code = '',
    required this.name,
    this.description = '',
    this.unit = 'und',
    required this.quantityMillis,
    required this.unitPrice,
    this.discountBps = 0,
    this.taxBps = 0,
    this.sortOrder = 0,
  });

  double get quantity => quantityMillis / 1000.0;

  factory QuoteLineItem.fromQuantity({
    required String id,
    String? catalogItemId,
    String code = '',
    required String name,
    String description = '',
    String unit = 'und',
    required num quantity,
    required MoneyCents unitPrice,
    int discountBps = 0,
    int taxBps = 0,
    int sortOrder = 0,
  }) {
    return QuoteLineItem(
      id: id,
      catalogItemId: catalogItemId,
      code: code,
      name: name,
      description: description,
      unit: unit,
      quantityMillis: (quantity * 1000).round(),
      unitPrice: unitPrice,
      discountBps: discountBps,
      taxBps: taxBps,
      sortOrder: sortOrder,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'catalogItemId': catalogItemId,
    'code': code,
    'name': name,
    'description': description,
    'unit': unit,
    'quantityMillis': quantityMillis,
    'unitPriceCents': unitPrice.cents,
    'discountBps': discountBps,
    'taxBps': taxBps,
    'sortOrder': sortOrder,
  };

  factory QuoteLineItem.fromMap(Map<String, dynamic> map) {
    final qtyMillis = map['quantityMillis'];
    final qty = map['quantity'];
    final resolvedMillis = qtyMillis is num
        ? qtyMillis.round()
        : qty is num
        ? (qty.toDouble() * 1000).round()
        : 1000;

    return QuoteLineItem(
      id: map['id'] as String? ?? '',
      catalogItemId: map['catalogItemId'] as String?,
      code: map['code'] as String? ?? '',
      name: map['name'] as String? ?? map['nombre'] as String? ?? '',
      description:
          map['description'] as String? ?? map['descripcion'] as String? ?? '',
      unit: map['unit'] as String? ?? 'und',
      quantityMillis: resolvedMillis,
      unitPrice: map['unitPriceCents'] != null
          ? MoneyCents((map['unitPriceCents'] as num).round())
          : MoneyCents.fromDecimal(map['precio'] ?? map['unitPrice'] ?? 0),
      discountBps: (map['discountBps'] as num?)?.round() ?? 0,
      taxBps: (map['taxBps'] as num?)?.round() ?? 0,
      sortOrder: (map['sortOrder'] as num?)?.round() ?? 0,
    );
  }

  QuoteLineItem copyWith({
    String? id,
    String? catalogItemId,
    String? code,
    String? name,
    String? description,
    String? unit,
    int? quantityMillis,
    MoneyCents? unitPrice,
    int? discountBps,
    int? taxBps,
    int? sortOrder,
  }) {
    return QuoteLineItem(
      id: id ?? this.id,
      catalogItemId: catalogItemId ?? this.catalogItemId,
      code: code ?? this.code,
      name: name ?? this.name,
      description: description ?? this.description,
      unit: unit ?? this.unit,
      quantityMillis: quantityMillis ?? this.quantityMillis,
      unitPrice: unitPrice ?? this.unitPrice,
      discountBps: discountBps ?? this.discountBps,
      taxBps: taxBps ?? this.taxBps,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

/// Resultado de totales de una cotización.
class QuoteTotals {
  final MoneyCents linesGross;
  final MoneyCents linesDiscount;
  final MoneyCents linesTax;
  final MoneyCents linesNet;
  final MoneyCents globalDiscount;
  final MoneyCents charges;
  final MoneyCents rounding;
  final MoneyCents total;

  const QuoteTotals({
    required this.linesGross,
    required this.linesDiscount,
    required this.linesTax,
    required this.linesNet,
    required this.globalDiscount,
    required this.charges,
    required this.rounding,
    required this.total,
  });
}

/// Calculadora determinista de totales (centavos).
class QuoteTotalsCalculator {
  const QuoteTotalsCalculator();

  QuoteTotals calculate({
    required List<QuoteLineItem> items,
    int globalDiscountBps = 0,
    MoneyCents globalDiscountFixed = MoneyCents.zero,
    MoneyCents charges = MoneyCents.zero,
  }) {
    var gross = MoneyCents.zero;
    var discount = MoneyCents.zero;
    var tax = MoneyCents.zero;
    var net = MoneyCents.zero;

    for (final item in items) {
      final line = lineAmounts(item);
      gross += line.gross;
      discount += line.discount;
      tax += line.tax;
      net += line.net;
    }

    var afterLines = net;
    final globalFromBps = afterLines.percentBps(globalDiscountBps);
    final globalDisc = globalFromBps + globalDiscountFixed;
    afterLines -= globalDisc;
    if (afterLines.isNegative) {
      afterLines = MoneyCents.zero;
    }

    final total = afterLines + charges;

    return QuoteTotals(
      linesGross: gross,
      linesDiscount: discount,
      linesTax: tax,
      linesNet: net,
      globalDiscount: globalDisc,
      charges: charges,
      rounding: MoneyCents.zero,
      total: total,
    );
  }

  /// Expuesto para pruebas unitarias de línea.
  ({MoneyCents gross, MoneyCents discount, MoneyCents tax, MoneyCents net})
  lineAmounts(QuoteLineItem item) {
    final grossCents = _divRoundHalfUp(
      item.unitPrice.cents * item.quantityMillis,
      1000,
    );
    final gross = MoneyCents(grossCents);
    final disc = gross.percentBps(item.discountBps);
    final afterDisc = gross - disc;
    final taxAmt = afterDisc.percentBps(item.taxBps);
    final net = afterDisc + taxAmt;
    return (gross: gross, discount: disc, tax: taxAmt, net: net);
  }

  int _divRoundHalfUp(int numerator, int denominator) {
    if (denominator == 0) throw ArgumentError('denominator');
    final negative = numerator < 0;
    final n = numerator.abs();
    final q = n ~/ denominator;
    final r = n % denominator;
    final rounded = q + (r * 2 >= denominator ? 1 : 0);
    return negative ? -rounded : rounded;
  }
}
