import 'dart:convert';
import 'package:universal_io/io.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/services.dart';
import 'package:docx_template_fork/docx_template_fork.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/cotizacion.dart';
import '../saas/domain/quote_totals.dart';
import '../saas/models/quote.dart';

class DocxService {
  static Map<String, String> _getColors(Cotizacion cot) {
    if (cot.coloresJson != null && cot.coloresJson!.isNotEmpty) {
      try {
        final colores = jsonDecode(cot.coloresJson!) as Map<String, dynamic>;
        return {
          'primary': colores['primary'] as String,
          'secondary': colores['secondary'] as String,
          'accent': colores['accent'] as String,
          'success': colores['success'] as String,
          'error': colores['error'] as String,
        };
      } catch (_) {}
    }
    // Colores por defecto
    return {
      'primary': '#1A1A2E',
      'secondary': '#2D6A4F',
      'accent': '#40916C',
      'success': '#D8F3DC',
      'error': '#FFE5E5',
    };
  }

  static Future<bool> generarYCompartirDocx(
    Cotizacion cot, {
    Quote? quote,
  }) async {
    if (kIsWeb) return false;

    try {
      final ByteData data = await rootBundle.load('assets/plantilla.docx');
      final bytes = data.buffer.asUint8List();

      final docx = await DocxTemplate.fromBytes(bytes);
      final currencyFormat = NumberFormat.currency(
        symbol: '\$',
        decimalDigits: 2,
      );

      Content content = Content();

      // —— 1. Campos de Texto Simples
      final colores = _getColors(cot);
      content
        ..add(TextContent("numero", cot.numero))
        ..add(TextContent("fecha", cot.fecha))
        ..add(TextContent("color_primary", colores['primary']!))
        ..add(TextContent("color_secondary", colores['secondary']!))
        ..add(TextContent("color_accent", colores['accent']!))
        ..add(TextContent("color_success", colores['success']!))
        ..add(TextContent("color_error", colores['error']!))
        ..add(TextContent("cliente", cot.cliente))
        ..add(TextContent("ubicacion", cot.ubicacion))
        ..add(TextContent("tipoServicio", cot.tipoServicio))
        ..add(TextContent("cantidadEquipos", cot.cantidadEquipos))
        ..add(TextContent("tiempoEstimado", cot.tiempoEstimado))
        ..add(TextContent("descripcion", cot.descripcion))
        ..add(TextContent("total", currencyFormat.format(cot.total)))
        ..add(TextContent("subtitulo", cot.subtitulo ?? ""))
        ..add(TextContent("validezDias", cot.validezDias?.toString() ?? "30"))
        ..add(TextContent("footerText", cot.footerText ?? ""))
        ..add(TextContent("estado", quote?.status.id ?? "draft"))
        ..add(
          TextContent(
            "firmaTecnico",
            cot.firmaTecnicoLabel ?? "Firma del Técnico",
          ),
        )
        ..add(
          TextContent(
            "firmaCliente",
            cot.firmaClienteLabel ?? "Firma del Cliente",
          ),
        );

      // —— 2. Listas
      content.add(
        ListContent(
          "listaIncluye",
          cot.incluye.map((item) => TextContent("itemIncluye", item)).toList(),
        ),
      );

      content.add(
        ListContent(
          "listaNoIncluye",
          cot.noIncluye
              .map((item) => TextContent("itemNoIncluye", item))
              .toList(),
        ),
      );

      content.add(
        ListContent(
          "listaNotas",
          cot.notas.map((item) => TextContent("itemNota", item)).toList(),
        ),
      );

      // —— 3. Tabla de Servicios (si hay Quote, descripción con qty/dto/imp)
      if (quote != null && quote.items.isNotEmpty) {
        const calc = QuoteTotalsCalculator();
        final filas = quote.items.map((item) {
          final line = calc.lineAmounts(item);
          final detail = StringBuffer(item.description);
          detail.write(
            ' | ${item.quantity} ${item.unit} × ${currencyFormat.format(item.unitPrice.asDecimal)}',
          );
          if (item.discountBps > 0) {
            detail.write(
              ' | dto ${(item.discountBps / 100).toStringAsFixed(1)}%',
            );
          }
          if (item.taxBps > 0) {
            detail.write(' | imp ${(item.taxBps / 100).toStringAsFixed(1)}%');
          }
          return RowContent()
            ..add(TextContent("nombreServicio", item.name))
            ..add(TextContent("descripcionServicio", detail.toString()))
            ..add(
              TextContent(
                "precioServicio",
                currencyFormat.format(line.net.asDecimal),
              ),
            );
        }).toList();
        content.add(TableContent("servicios", filas));
      } else if (cot.servicios.isNotEmpty) {
        final filas = cot.servicios
            .map(
              (s) => RowContent()
                ..add(TextContent("nombreServicio", s.nombre))
                ..add(TextContent("descripcionServicio", s.descripcion))
                ..add(
                  TextContent(
                    "precioServicio",
                    currencyFormat.format(s.precio),
                  ),
                ),
            )
            .toList();
        content.add(TableContent("servicios", filas));
      }

      final docBytes = await docx.generate(content);

      if (docBytes != null) {
        final tempDir = await getTemporaryDirectory();
        final safeNum = cot.numero.replaceAll(RegExp(r'[^\w\-]'), '_');
        final file = File('${tempDir.path}/Cotizacion_$safeNum.docx');
        await file.writeAsBytes(docBytes);

        await Share.shareXFiles([
          XFile(file.path),
        ], text: 'Cotización ${cot.numero}');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("ERROR DOCX: $e");
      return false;
    }
  }
}
