import 'dart:convert';
import 'dart:typed_data';
import 'package:universal_io/io.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

import '../models/cotizacion.dart';
import '../models/forma_pago_item.dart';
import '../models/servicio.dart';
import '../saas/domain/quote_totals.dart';
import '../saas/models/quote.dart';
import '../saas/services/branding_storage_service.dart';
import '../saas/services/quote_mapper.dart';

class _PdfColors {
  static PdfColor parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return PdfColors.black;
    try {
      String cleanedHex = hex.replaceAll('#', '').toUpperCase();
      if (cleanedHex.length == 6) cleanedHex = 'FF$cleanedHex';
      int value = int.parse(cleanedHex, radix: 16);
      return PdfColor.fromInt(value);
    } catch (_) {
      return PdfColors.black;
    }
  }

  static late PdfColor primary;
  static late PdfColor secondary;
  static late PdfColor accent;

  // Colores adicionales para el PDF
  static final PdfColor textDark = PdfColor.fromHex('#333333');
  static final PdfColor textGray = PdfColor.fromHex('#666666');
  static final PdfColor border = PdfColor.fromHex('#CCCCCC');

  static void initialize(Map<String, dynamic>? coloresJson) {
    primary = parseColor(coloresJson?['primary'] as String? ?? '#1A1A2E');
    secondary = parseColor(coloresJson?['secondary'] as String? ?? '#2D6A4F');
    accent = parseColor(coloresJson?['accent'] as String? ?? '#40916C');
  }
}

void _setupColors(Cotizacion cot) {
  final Map<String, dynamic>? coloresJson =
      cot.coloresJson != null && cot.coloresJson!.isNotEmpty
      ? jsonDecode(cot.coloresJson!) as Map<String, dynamic>
      : null;
  _PdfColors.initialize(coloresJson);
}

class PdfService {
  /// Genera PDF desde dominio [Quote] (columnas qty/precio/dto/imp/neto).
  static Future<Uint8List> generarPDFFromQuote(Quote quote) async {
    final cot = QuoteMapper.toCotizacion(quote);
    return _build(cot: cot, quote: quote);
  }

  static Future<Uint8List> generarPDF(Cotizacion cot, {Quote? quote}) async {
    return _build(cot: cot, quote: quote);
  }

  static Future<Uint8List> _build({
    required Cotizacion cot,
    Quote? quote,
  }) async {
    _setupColors(cot);
    final pdf = pw.Document();
    final currencyFormat = NumberFormat.currency(
      symbol: '\$',
      decimalDigits: 2,
    );

    pw.ImageProvider? logoImage;
    final logoBytes = await BrandingStorageService.instance.loadLogoBytes(
      cot.logoPath ?? quote?.logoPath,
    );
    if (logoBytes != null) {
      logoImage = pw.MemoryImage(logoBytes);
    } else if (cot.logoPath != null &&
        cot.logoPath!.isNotEmpty &&
        !cot.logoPath!.startsWith('data:') &&
        !cot.logoPath!.startsWith('http') &&
        !kIsWeb) {
      try {
        final file = File(cot.logoPath!);
        if (await file.exists()) {
          logoImage = pw.MemoryImage(await file.readAsBytes());
        }
      } catch (_) {}
    }

    final subtitulo = cot.subtitulo ?? cot.tipoServicio;
    final validez = cot.validezDias != null
        ? 'Validez: ${cot.validezDias} dias'
        : '';
    final firmaTecnico = cot.firmaTecnicoLabel ?? 'Firma del Tecnico';
    final firmaCliente = cot.firmaClienteLabel ?? 'Firma del Cliente';
    final statusLabel = quote?.status.id;
    const calc = QuoteTotalsCalculator();
    final totals = quote == null
        ? null
        : calc.calculate(
            items: quote.items,
            globalDiscountBps: quote.globalDiscountBps,
            globalDiscountFixed: quote.globalDiscountFixed,
            charges: quote.charges,
          );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        footer: cot.footerText == null || cot.footerText!.isEmpty
            ? null
            : (context) => pw.Text(
                cot.footerText!,
                style: pw.TextStyle(color: _PdfColors.textGray, fontSize: 8),
                textAlign: pw.TextAlign.center,
              ),
        build: (context) => [
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FixedColumnWidth(140),
            },
            children: [
              pw.TableRow(
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.all(16),
                    decoration: pw.BoxDecoration(color: _PdfColors.primary),
                    child: pw.Row(
                      children: [
                        if (logoImage != null)
                          pw.Container(
                            width: 48,
                            height: 48,
                            margin: const pw.EdgeInsets.only(right: 12),
                            child: pw.Image(logoImage, fit: pw.BoxFit.cover),
                          ),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            mainAxisSize: pw.MainAxisSize.min,
                            children: [
                              pw.Text(
                                'COTIZACION DE SERVICIOS',
                                style: pw.TextStyle(
                                  color: PdfColors.white,
                                  fontSize: 16,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              if (subtitulo.isNotEmpty)
                                pw.Text(
                                  subtitulo,
                                  style: pw.TextStyle(
                                    color: PdfColors.white,
                                    fontSize: 9,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(color: _PdfColors.secondary),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Text(
                          'Nro. ${cot.numero}',
                          style: pw.TextStyle(
                            color: _PdfColors.textDark,
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          'Fecha: ${cot.fecha}',
                          style: pw.TextStyle(
                            color: _PdfColors.textDark,
                            fontSize: 9,
                          ),
                        ),
                        if (validez.isNotEmpty)
                          pw.Text(
                            validez,
                            style: pw.TextStyle(
                              color: _PdfColors.textDark,
                              fontSize: 9,
                            ),
                          ),
                        if (statusLabel != null)
                          pw.Text(
                            'Estado: $statusLabel',
                            style: pw.TextStyle(
                              color: _PdfColors.textDark,
                              fontSize: 8,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 20),
          _tituloSeccion('INFORMACION DEL PROYECTO'),
          pw.SizedBox(height: 8),
          _tablaInformacionProyecto(cot),

          if (cot.descripcion.isNotEmpty) ...[
            pw.SizedBox(height: 15),
            _tituloSeccion('DESCRIPCION GENERAL'),
            pw.SizedBox(height: 5),
            pw.Text(
              cot.descripcion,
              style: pw.TextStyle(color: _PdfColors.textGray, fontSize: 9),
              textAlign: pw.TextAlign.justify,
            ),
          ],

          pw.SizedBox(height: 15),
          _tituloSeccion('DETALLE DE SERVICIOS'),
          pw.SizedBox(height: 8),
          if (quote != null && quote.items.isNotEmpty)
            _tablaLineasQuote(quote.items, currencyFormat, calc)
          else
            _tablaServicios(cot.servicios, currencyFormat),

          if (totals != null) ...[
            pw.SizedBox(height: 8),
            _resumenTotales(totals, currencyFormat),
          ],

          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: pw.BoxDecoration(color: _PdfColors.accent),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'TOTAL DEL PROYECTO',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
                pw.Text(
                  currencyFormat.format(totals?.total.asDecimal ?? cot.total),
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 15),
          _tituloSeccion('FORMA DE PAGO'),
          pw.SizedBox(height: 8),
          _bloquesFormaPago(cot, currencyFormat),

          pw.SizedBox(height: 15),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: _bloqueLista('INCLUYE', cot.incluye)),
              pw.SizedBox(width: 12),
              pw.Expanded(child: _bloqueLista('NO INCLUYE', cot.noIncluye)),
            ],
          ),

          if (cot.notas.isNotEmpty) ...[
            pw.SizedBox(height: 15),
            _tituloSeccion('NOTAS IMPORTANTES'),
            ...cot.notas.map(
              (n) => pw.Padding(
                padding: const pw.EdgeInsets.only(top: 2),
                child: pw.Text(
                  '- $n',
                  style: pw.TextStyle(
                    color: _PdfColors.textGray,
                    fontSize: 8.5,
                  ),
                ),
              ),
            ),
          ],

          if (cot.camposExtra != null && cot.camposExtra!.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            _tituloSeccion('CAMPOS ADICIONALES'),
            pw.Text(
              cot.camposExtra!,
              style: pw.TextStyle(color: _PdfColors.textGray, fontSize: 8.5),
            ),
          ],

          pw.SizedBox(height: 40),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [_lineaFirma(firmaTecnico), _lineaFirma(firmaCliente)],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _resumenTotales(QuoteTotals t, NumberFormat fmt) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        _totLine('Subtotal', fmt.format(t.linesGross.asDecimal)),
        if (t.linesDiscount.cents > 0)
          _totLine('Descuentos', '-${fmt.format(t.linesDiscount.asDecimal)}'),
        if (t.linesTax.cents > 0)
          _totLine('Impuestos', fmt.format(t.linesTax.asDecimal)),
        if (t.globalDiscount.cents > 0)
          _totLine(
            'Descuento global',
            '-${fmt.format(t.globalDiscount.asDecimal)}',
          ),
        if (t.charges.cents > 0)
          _totLine('Cargos', fmt.format(t.charges.asDecimal)),
      ],
    );
  }

  static pw.Widget _totLine(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Text(
            '$label: ',
            style: pw.TextStyle(fontSize: 8, color: _PdfColors.textGray),
          ),
          pw.Text(value, style: const pw.TextStyle(fontSize: 8.5)),
        ],
      ),
    );
  }

  static pw.Widget _tablaLineasQuote(
    List<QuoteLineItem> items,
    NumberFormat fmt,
    QuoteTotalsCalculator calc,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: _PdfColors.border, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(2.2),
        1: const pw.FlexColumnWidth(0.7),
        2: const pw.FlexColumnWidth(1.0),
        3: const pw.FlexColumnWidth(0.7),
        4: const pw.FlexColumnWidth(0.7),
        5: const pw.FlexColumnWidth(1.0),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _PdfColors.primary),
          children: [
            for (final h in [
              'SERVICIO',
              'CANT',
              'P.UNIT',
              'DTO%',
              'IMP%',
              'NETO',
            ])
              pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text(
                  h,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 7.5,
                  ),
                ),
              ),
          ],
        ),
        ...items.map((item) {
          final line = calc.lineAmounts(item);
          return pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      item.name,
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (item.description.isNotEmpty)
                      pw.Text(
                        item.description,
                        style: pw.TextStyle(
                          fontSize: 7,
                          color: _PdfColors.textGray,
                        ),
                      ),
                  ],
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text(
                  '${item.quantity} ${item.unit}',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text(
                  fmt.format(item.unitPrice.asDecimal),
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text(
                  (item.discountBps / 100).toStringAsFixed(1),
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text(
                  (item.taxBps / 100).toStringAsFixed(1),
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text(
                  fmt.format(line.net.asDecimal),
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _tituloSeccion(String titulo) {
    return pw.Text(
      titulo,
      style: pw.TextStyle(
        fontSize: 11,
        fontWeight: pw.FontWeight.bold,
        color: _PdfColors.textDark,
      ),
    );
  }

  static pw.Widget _tablaInformacionProyecto(Cotizacion cot) {
    return pw.Table(
      border: pw.TableBorder.all(color: _PdfColors.border, width: 0.5),
      children: [
        pw.TableRow(
          children: [
            _celdaInfo('CLIENTE', cot.cliente),
            _celdaInfo('TIPO PROYECTO', cot.tipoServicio),
          ],
        ),
        pw.TableRow(
          children: [
            _celdaInfo('UBICACION', cot.ubicacion),
            _celdaInfo('TIEMPO ESTIMADO', cot.tiempoEstimado),
          ],
        ),
      ],
    );
  }

  static pw.Widget _celdaInfo(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: _PdfColors.textGray,
            ),
          ),
          pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  static pw.Widget _tablaServicios(List<Servicio> servicios, NumberFormat fmt) {
    return pw.Table(
      border: pw.TableBorder.all(color: _PdfColors.border, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _PdfColors.primary),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(
                'SERVICIO',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 9,
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(
                'DESCRIPCION',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 9,
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(
                'PRECIO',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 9,
                ),
              ),
            ),
          ],
        ),
        ...servicios.map(
          (s) => pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  s.nombre,
                  style: const pw.TextStyle(fontSize: 8.5),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  s.descripcion,
                  style: const pw.TextStyle(fontSize: 8.5),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  fmt.format(s.precio),
                  style: const pw.TextStyle(fontSize: 8.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _bloquesFormaPago(Cotizacion cot, NumberFormat fmt) {
    final t = cot.total;
    // Usar formaPago personalizada si está disponible, de lo contrario usar default
    final List<FormaPagoItem> items;
    if (cot.formaPago.isNotEmpty) {
      items = cot.formaPago;
    } else {
      items = [
        FormaPagoItem(
          etiqueta: 'ANTICIPO',
          descripcion: '50% inicio',
          monto: t * 0.5,
        ),
        FormaPagoItem(
          etiqueta: 'ENTREGA',
          descripcion: '25% mitad',
          monto: t * 0.25,
        ),
        FormaPagoItem(
          etiqueta: 'SALDO',
          descripcion: '25% final',
          monto: t * 0.25,
        ),
      ];
    }

    return pw.Table(
      children: [
        pw.TableRow(
          children: items
              .map(
                (item) => pw.Container(
                  margin: const pw.EdgeInsets.symmetric(horizontal: 2),
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: _PdfColors.secondary,
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(4),
                    ),
                  ),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Text(
                        item.etiqueta,
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        fmt.format(item.monto),
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  static pw.Widget _bloqueLista(String titulo, List<String> items) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _PdfColors.border, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(
            titulo,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
          ),
          pw.SizedBox(height: 4),
          ...items.map(
            (i) => pw.Text('- $i', style: const pw.TextStyle(fontSize: 8)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _lineaFirma(String label) {
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(
          width: 140,
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(width: 0.5)),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
      ],
    );
  }
}
