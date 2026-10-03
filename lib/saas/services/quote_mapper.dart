import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../core/utils/money_cents.dart';
import '../../models/cotizacion.dart';
import '../../models/forma_pago_item.dart';
import '../../models/servicio.dart';
import '../domain/org_enums.dart';
import '../domain/quote_totals.dart';
import '../models/quote.dart';

/// Adaptador entre el modelo UI legacy [Cotizacion] y el dominio [Quote].
class QuoteMapper {
  QuoteMapper._();

  static const _calc = QuoteTotalsCalculator();

  static Quote fromCotizacion(
    Cotizacion cot, {
    required String organizationId,
    required String createdByUid,
    QuoteStatus status = QuoteStatus.draft,
    int sequence = 0,
    String? clientId,
    String currency = 'USD',
    String? legacyUserPath,
  }) {
    final items = <QuoteLineItem>[];
    for (var i = 0; i < cot.servicios.length; i++) {
      final s = cot.servicios[i];
      items.add(
        QuoteLineItem.fromQuantity(
          id: const Uuid().v4(),
          name: s.nombre,
          description: s.descripcion,
          quantity: 1,
          unitPrice: MoneyCents.fromDecimal(s.precio),
          sortOrder: i,
        ),
      );
    }

    final payments = cot.formaPago
        .map(
          (p) => {
            'label': p.etiqueta,
            'description': p.descripcion,
            'amountCents': MoneyCents.fromDecimal(p.monto).cents,
          },
        )
        .toList();

    final totals = _calc.calculate(items: items);
    final issue =
        DateTime.tryParse(cot.fecha)?.toUtc() ?? DateTime.now().toUtc();
    DateTime? due;
    if (cot.validezDias != null) {
      due = issue.add(Duration(days: cot.validezDias!));
    }

    return Quote(
      id: cot.id,
      organizationId: organizationId,
      number: cot.numero,
      sequence: sequence,
      status: status,
      clientId: clientId,
      clientName: cot.cliente,
      issueDate: issue,
      dueDate: due,
      currency: currency,
      items: items,
      total: MoneyCents.fromDecimal(cot.total),
      includes: cot.incluye,
      excludes: cot.noIncluye,
      notes: cot.notas,
      payments: payments,
      logoPath: cot.logoPath,
      colorsJson: cot.coloresJson,
      subtitle: cot.subtitulo,
      footerText: cot.footerText,
      extraFields: cot.camposExtra,
      createdByUid: createdByUid,
      legacyUserPath: legacyUserPath,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
      legacyFields: {
        'ubicacion': cot.ubicacion,
        'tipoServicio': cot.tipoServicio,
        'cantidadEquipos': cot.cantidadEquipos,
        'tiempoEstimado': cot.tiempoEstimado,
        'descripcion': cot.descripcion,
        'firmaTecnicoLabel': cot.firmaTecnicoLabel,
        'firmaClienteLabel': cot.firmaClienteLabel,
        'validezDias': cot.validezDias,
        // Conserva total legacy si difiere del recalculado.
        'legacyTotalCents': MoneyCents.fromDecimal(cot.total).cents,
        'computedTotalCents': totals.total.cents,
      },
    );
  }

  static Cotizacion toCotizacion(Quote quote) {
    const calc = QuoteTotalsCalculator();
    // PDF/DOCX legacy: una celda de importe por línea = neto tras dto/impuesto.
    final servicios = quote.items.map((i) {
      final line = calc.lineAmounts(i);
      final detail = StringBuffer(i.description);
      if (i.quantity != 1 || i.discountBps > 0 || i.taxBps > 0) {
        if (detail.isNotEmpty) detail.write(' · ');
        detail.write('${i.quantity} ${i.unit} × ${i.unitPrice.format()}');
        if (i.discountBps > 0) {
          detail.write(' · dto ${(i.discountBps / 100).toStringAsFixed(1)}%');
        }
        if (i.taxBps > 0) {
          detail.write(' · imp ${(i.taxBps / 100).toStringAsFixed(1)}%');
        }
      }
      return Servicio(
        nombre: i.name,
        descripcion: detail.toString(),
        precio: line.net.asDecimal,
      );
    }).toList();

    final formaPago = quote.payments
        .map(
          (p) => FormaPagoItem(
            etiqueta: '${p['label'] ?? ''}',
            descripcion: '${p['description'] ?? ''}',
            monto: MoneyCents(
              (p['amountCents'] as num?)?.round() ?? 0,
            ).asDecimal,
          ),
        )
        .toList();

    final legacy = quote.legacyFields;
    return Cotizacion(
      id: quote.id,
      numero: quote.number,
      fecha: quote.issueDate.toIso8601String().split('T').first,
      cliente: quote.clientName,
      ubicacion: '${legacy['ubicacion'] ?? ''}',
      tipoServicio: '${legacy['tipoServicio'] ?? ''}',
      cantidadEquipos: '${legacy['cantidadEquipos'] ?? ''}',
      tiempoEstimado: '${legacy['tiempoEstimado'] ?? ''}',
      descripcion: '${legacy['descripcion'] ?? ''}',
      servicios: servicios,
      total: quote.total.asDecimal,
      incluye: quote.includes,
      noIncluye: quote.excludes,
      notas: quote.notes,
      logoPath: quote.logoPath,
      subtitulo: quote.subtitle,
      validezDias:
          legacy['validezDias'] as int? ??
          quote.dueDate?.difference(quote.issueDate).inDays,
      footerText: quote.footerText,
      firmaTecnicoLabel: legacy['firmaTecnicoLabel'] as String?,
      firmaClienteLabel: legacy['firmaClienteLabel'] as String?,
      formaPagoJson: formaPago.isEmpty
          ? null
          : jsonEncode(formaPago.map((e) => e.toJson()).toList()),
      camposExtra: quote.extraFields,
      coloresJson: quote.colorsJson,
      quoteStatus: quote.status.id,
    );
  }
}
