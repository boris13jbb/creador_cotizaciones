import 'dart:convert';

import 'catalog_import_headers.dart';

/// Codificación UTF-8 de CSV de catálogo (compatible con Excel).
class CatalogCsvCodec {
  CatalogCsvCodec._();
  static final CatalogCsvCodec instance = CatalogCsvCodec._();

  /// Cabecera canónica (inglés) — la que reconoce el importador de forma estable.
  static const String templateHeader =
      'code,name,description,category,unit,unitPrice,taxPercent';

  /// BOM UTF-8 + cabecera canónica + filas de ejemplo.
  ///
  /// Los textos de ejemplo se localizan; los encabezados siempre son canónicos
  /// para evitar desajustes entre plantilla e importador.
  String buildTemplate({required bool spanishLabels}) {
    final rows = <String>[
      templateHeader,
      _csvLine([
        'EJEMPLO-001',
        spanishLabels ? 'Servicio de consultoría' : 'Consulting service',
        spanishLabels
            ? 'Fila de ejemplo - no se importa'
            : 'Example row - skipped on import',
        'General',
        'und',
        '50.00',
        '0',
      ]),
      _csvLine([
        'EJEMPLO-002',
        spanishLabels ? 'Producto con ñ y tildes' : 'Product with accents',
        spanishLabels
            ? 'Fila de ejemplo - no se importa. Descripción, con comas y "comillas"'
            : 'Example row - skipped on import. Description, with commas and "quotes"',
        spanishLabels ? 'Categoría' : 'Category',
        'und',
        '12.5',
        '12',
      ]),
    ];
    // BOM para que Excel abra UTF-8 correctamente.
    return '\uFEFF${rows.join('\r\n')}\r\n';
  }

  /// Decodifica bytes UTF-8 (con o sin BOM) a tabla de celdas.
  List<List<String>> decodeBytes(List<int> bytes) {
    var text = utf8.decode(bytes, allowMalformed: false);
    if (text.startsWith('\uFEFF')) {
      text = text.substring(1);
    }
    return decodeText(text);
  }

  List<List<String>> decodeText(String csv) {
    final normalized = csv.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = normalized.split('\n');
    while (lines.isNotEmpty && lines.last.trim().isEmpty) {
      lines.removeLast();
    }
    return lines.map(splitCsvLine).toList();
  }

  /// Split CSV respetando comillas dobles y comas escapadas.
  List<String> splitCsvLine(String line) {
    final out = <String>[];
    final buf = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (c == ',' && !inQuotes) {
        out.add(buf.toString());
        buf.clear();
      } else {
        buf.write(c);
      }
    }
    out.add(buf.toString());
    return out;
  }

  String _csvLine(List<String> cells) => cells.map(_escape).join(',');

  String _escape(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  List<String> get canonicalHeaders => CatalogImportHeaders.canonical;
}
