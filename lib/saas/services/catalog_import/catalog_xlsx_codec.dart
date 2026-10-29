import 'dart:convert';

import 'package:archive/archive.dart';

// Excel Desktop suele rechazar ZIP con el bit UTF-8 (0x800) en entradas
// cuando los nombres de archivo son ASCII. Usamos Latin-1 para rutas.
final Encoding _zipPathEncoding = latin1;

/// Lectura/escritura de `.xlsx` (OOXML) compatible con Excel / LibreOffice.
///
/// Usa `archive` (ya en el proyecto). No admite el formato binario legacy `.xls`.
/// Las celdas de texto van por `sharedStrings` (Excel suele fallar o vaciar
/// plantillas basadas solo en `inlineStr` + `styles.xml` incompleto).
class CatalogXlsxCodec {
  CatalogXlsxCodec._();
  static final CatalogXlsxCodec instance = CatalogXlsxCodec._();

  static const productsSheetName = 'Productos';
  static const instructionsSheetName = 'Instrucciones';

  /// Genera un `.xlsx` válido con hoja de instrucciones y hoja de productos.
  ///
  /// Los encabezados de Productos son siempre canónicos en inglés
  /// (`code,name,...`); el importador también acepta alias ES al leer.
  List<int> buildTemplate({required bool spanishLabels}) {
    const headers = [
      'code',
      'name',
      'description',
      'category',
      'unit',
      'unitPrice',
      'taxPercent',
    ];

    final example1 = <Object>[
      'EJEMPLO-001',
      spanishLabels ? 'Servicio de consultoría' : 'Consulting service',
      spanishLabels
          ? 'Fila de ejemplo - no se importa'
          : 'Example row - skipped on import',
      'General',
      'und',
      50.0,
      0,
    ];
    final example2 = <Object>[
      'EJEMPLO-002',
      spanishLabels ? 'Producto con ñ y tildes' : 'Product with accents',
      spanishLabels
          ? 'Fila de ejemplo - no se importa. Descripción, con comas'
          : 'Example row - skipped on import. Description, with commas',
      spanishLabels ? 'Categoría' : 'Category',
      'und',
      12.5,
      12,
    ];

    final instructions = spanishLabels
        ? const [
            ['Plantilla de importación de catálogo CotiApp'],
            [''],
            ['Campos:'],
            [
              'codigo',
              'Opcional. Identificador estable (SKU). Usado para detectar duplicados.',
            ],
            ['nombre', 'Obligatorio.'],
            ['descripcion', 'Opcional.'],
            ['categoria', 'Opcional. Por defecto: General.'],
            ['unidad', 'Opcional. Por defecto: und.'],
            [
              'precio',
              'Opcional. Precio de venta (>= 0). Usa punto o coma decimal.',
            ],
            ['impuesto', 'Opcional. Porcentaje de impuesto (>= 0), p. ej. 12.'],
            [''],
            [
              'Las filas de ejemplo (codigo EJEMPLO/EXAMPLE y texto "no se importa") se ignoran. Si las editas con productos reales, se importan.',
            ],
            [
              'No se admiten macros. Complete la hoja Productos y guarde el archivo.',
            ],
          ]
        : const [
            ['CotiApp catalog import template'],
            [''],
            ['Fields:'],
            ['code', 'Optional. Stable SKU. Used for duplicate detection.'],
            ['name', 'Required.'],
            ['description', 'Optional.'],
            ['category', 'Optional. Default: General.'],
            ['unit', 'Optional. Default: und.'],
            [
              'unitPrice',
              'Optional. Selling price (>= 0). Dot or comma decimals.',
            ],
            ['taxPercent', 'Optional. Tax percent (>= 0), e.g. 12.'],
            [''],
            [
              'Example rows (EJEMPLO/EXAMPLE code plus "skipped on import" text) are skipped. Edited real products are imported.',
            ],
            ['No macros. Fill the Productos sheet and save the file.'],
          ];

    final products = <List<Object>>[headers, example1, example2];
    return _encodeWorkbook({
      instructionsSheetName: instructions,
      productsSheetName: products,
    }, defaultSheet: productsSheetName);
  }

  /// Lee la hoja de productos (prioriza "Productos" / "Products").
  /// Devuelve filas como listas de strings (incluye cabecera).
  List<List<String>> decodeBytes(List<int> bytes) {
    Archive archive;
    try {
      // verify:false: Excel a veces escribe ZIP con descriptors que fallan verify.
      archive = ZipDecoder().decodeBytes(bytes, verify: false);
    } catch (e) {
      throw FormatException('Archivo XLSX inválido o corrupto: $e');
    }

    final sharedStrings = _readSharedStrings(archive);
    final sheets = _listSheets(archive);
    if (sheets.isEmpty) {
      throw const FormatException('El libro Excel no tiene hojas');
    }

    final preferred = sheets.where((s) {
      final n = s.name.toLowerCase().trim();
      return n == 'productos' ||
          n == 'products' ||
          n == 'catalogo' ||
          n == 'catálogo' ||
          n == 'catalog';
    });
    final target = preferred.isNotEmpty ? preferred.first : sheets.last;

    return _readSheetRows(archive, target.path, sharedStrings);
  }

  // ─── Writer ───────────────────────────────────────────────────────────────

  List<int> _encodeWorkbook(
    Map<String, List<List<Object>>> sheets, {
    required String defaultSheet,
  }) {
    final names = sheets.keys.toList();
    final shared = <String>[];
    int intern(String value) {
      final i = shared.indexOf(value);
      if (i >= 0) return i;
      shared.add(value);
      return shared.length - 1;
    }

    final archive = Archive();

    void addXml(String path, String xml) {
      final data = utf8.encode(xml);
      archive.addFile(ArchiveFile.bytes(path, data));
    }

    addXml(
      '[Content_Types].xml',
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
  <Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>
${[for (var i = 0; i < names.length; i++) '  <Override PartName="/xl/worksheets/sheet${i + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'].join('\n')}
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
</Types>''',
    );

    addXml(
      '_rels/.rels',
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>''',
    );

    addXml(
      'docProps/core.xml',
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:title>CotiApp catalog template</dc:title>
  <dc:creator>CotiApp</dc:creator>
  <cp:lastModifiedBy>CotiApp</cp:lastModifiedBy>
  <dcterms:created xsi:type="dcterms:W3CDTF">2026-01-01T00:00:00Z</dcterms:created>
  <dcterms:modified xsi:type="dcterms:W3CDTF">2026-01-01T00:00:00Z</dcterms:modified>
</cp:coreProperties>''',
    );

    addXml(
      'docProps/app.xml',
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
  <Application>CotiApp</Application>
  <HeadingPairs>
    <vt:vector size="2" baseType="variant">
      <vt:variant><vt:lpstr>Worksheets</vt:lpstr></vt:variant>
      <vt:variant><vt:i4>${names.length}</vt:i4></vt:variant>
    </vt:vector>
  </HeadingPairs>
  <TitlesOfParts>
    <vt:vector size="${names.length}" baseType="lpstr">
${names.map((n) => '      <vt:lpstr>${_xmlEscape(n)}</vt:lpstr>').join('\n')}
    </vt:vector>
  </TitlesOfParts>
</Properties>''',
    );

    // Excel exige al menos 2 fills (none + gray125) y xf con ids explícitos.
    addXml(
      'xl/styles.xml',
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <fonts count="1">
    <font><sz val="11"/><color theme="1"/><name val="Calibri"/><family val="2"/><scheme val="minor"/></font>
  </fonts>
  <fills count="2">
    <fill><patternFill patternType="none"/></fill>
    <fill><patternFill patternType="gray125"/></fill>
  </fills>
  <borders count="1">
    <border><left/><right/><top/><bottom/><diagonal/></border>
  </borders>
  <cellStyleXfs count="1">
    <xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>
  </cellStyleXfs>
  <cellXfs count="2">
    <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
    <xf numFmtId="2" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>
  </cellXfs>
  <cellStyles count="1">
    <cellStyle name="Normal" xfId="0" builtinId="0"/>
  </cellStyles>
</styleSheet>''',
    );

    final sheetXmls = <String>[];
    for (final name in names) {
      sheetXmls.add(_worksheetXml(sheets[name]!, intern));
    }

    final sstCount = shared.length;
    final sstBuf = StringBuffer();
    sstBuf.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    sstBuf.writeln(
      '<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="$sstCount" uniqueCount="$sstCount">',
    );
    for (final s in shared) {
      sstBuf.writeln('<si><t xml:space="preserve">${_xmlEscape(s)}</t></si>');
    }
    sstBuf.writeln('</sst>');
    addXml('xl/sharedStrings.xml', sstBuf.toString());

    final sheetRels = <String>[];
    for (var i = 0; i < names.length; i++) {
      sheetRels.add(
        '  <Relationship Id="rId${i + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet${i + 1}.xml"/>',
      );
    }
    final stylesRid = names.length + 1;
    final sstRid = names.length + 2;
    sheetRels.add(
      '  <Relationship Id="rId$stylesRid" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>',
    );
    sheetRels.add(
      '  <Relationship Id="rId$sstRid" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>',
    );

    addXml(
      'xl/_rels/workbook.xml.rels',
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
${sheetRels.join('\n')}
</Relationships>''',
    );

    final sheetEntries = <String>[];
    for (var i = 0; i < names.length; i++) {
      final name = _xmlEscape(names[i]);
      sheetEntries.add(
        '  <sheet name="$name" sheetId="${i + 1}" r:id="rId${i + 1}"/>',
      );
    }

    final activeIndex = names
        .indexOf(defaultSheet)
        .clamp(0, names.isEmpty ? 0 : names.length - 1);
    // Excel Desktop rechaza workbook.xml demasiado mínimo (p. ej. workbookPr
    // vacío / fileVersion sin atributos) con error 0x800A03EC al abrir.
    addXml(
      'xl/workbook.xml',
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <fileVersion appName="xl" lastEdited="7" lowestEdited="7" rupBuild="10000"/>
  <workbookPr defaultThemeVersion="124226"/>
  <bookViews>
    <workbookView xWindow="0" yWindow="0" windowWidth="20000" windowHeight="15000" activeTab="$activeIndex"/>
  </bookViews>
  <sheets>
${sheetEntries.join('\n')}
  </sheets>
  <calcPr calcId="191029"/>
</workbook>''',
    );

    for (var i = 0; i < names.length; i++) {
      addXml('xl/worksheets/sheet${i + 1}.xml', sheetXmls[i]);
    }

    return ZipEncoder(filenameEncoding: _zipPathEncoding).encode(archive);
  }

  String _worksheetXml(List<List<Object>> rows, int Function(String) intern) {
    final buf = StringBuffer();
    buf.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    buf.writeln(
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">',
    );
    if (rows.isNotEmpty) {
      final maxCol = rows
          .map((r) => r.length)
          .fold<int>(0, (a, b) => a > b ? a : b);
      if (maxCol > 0) {
        final end = '${_colName(maxCol - 1)}${rows.length}';
        buf.writeln('<dimension ref="A1:$end"/>');
      }
    }
    buf.writeln('<sheetData>');
    for (var r = 0; r < rows.length; r++) {
      final rowNum = r + 1;
      buf.write('<row r="$rowNum">');
      final cells = rows[r];
      for (var c = 0; c < cells.length; c++) {
        final ref = '${_colName(c)}$rowNum';
        final value = cells[c];
        if (value is num) {
          // Estilo 1 = número con 2 decimales (numFmtId=2).
          final style = value is int ? '' : ' s="1"';
          buf.write('<c r="$ref"$style><v>$value</v></c>');
        } else {
          final idx = intern(value.toString());
          buf.write('<c r="$ref" t="s"><v>$idx</v></c>');
        }
      }
      buf.write('</row>');
    }
    buf.writeln('</sheetData>');
    buf.writeln('</worksheet>');
    return buf.toString();
  }

  String _colName(int index) {
    var n = index;
    final chars = StringBuffer();
    do {
      chars.write(String.fromCharCode(65 + (n % 26)));
      n = (n ~/ 26) - 1;
    } while (n >= 0);
    return chars.toString().split('').reversed.join();
  }

  String _xmlEscape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  // ─── Reader ───────────────────────────────────────────────────────────────

  List<String> _readSharedStrings(Archive archive) {
    final file = _findFile(archive, 'xl/sharedStrings.xml');
    if (file == null) return const [];
    final xml = utf8.decode(file.content);
    final out = <String>[];
    final siRe = RegExp(r'<si>(.*?)</si>', dotAll: true);
    final tRe = RegExp(r'<t(?:\s[^>]*)?>(.*?)</t>', dotAll: true);
    for (final m in siRe.allMatches(xml)) {
      final inner = m.group(1) ?? '';
      final parts = tRe
          .allMatches(inner)
          .map((t) => _xmlUnescape(t.group(1) ?? ''));
      out.add(parts.join());
    }
    return out;
  }

  List<_XlsxSheetRef> _listSheets(Archive archive) {
    final wb = _findFile(archive, 'xl/workbook.xml');
    final rels = _findFile(archive, 'xl/_rels/workbook.xml.rels');
    if (wb == null || rels == null) return const [];

    final wbXml = utf8.decode(wb.content);
    final relsXml = utf8.decode(rels.content);

    final idToTarget = <String, String>{};
    final relRe = RegExp(r'<Relationship\b([^>]*)/>', dotAll: true);
    for (final m in relRe.allMatches(relsXml)) {
      final attrs = m.group(1) ?? '';
      final id = RegExp(r'\bId="([^"]+)"').firstMatch(attrs)?.group(1);
      final target = RegExp(r'\bTarget="([^"]+)"').firstMatch(attrs)?.group(1);
      if (id != null && target != null) {
        idToTarget[id] = target;
      }
    }

    final sheets = <_XlsxSheetRef>[];
    final sheetTagRe = RegExp(r'<sheet\b([^>]*)/>', dotAll: true);
    for (final m in sheetTagRe.allMatches(wbXml)) {
      final attrs = m.group(1) ?? '';
      final name = RegExp(r'\bname="([^"]+)"').firstMatch(attrs)?.group(1);
      final rid =
          RegExp(r'\br:id="([^"]+)"').firstMatch(attrs)?.group(1) ??
          RegExp(r'\bid="([^"]+)"').firstMatch(attrs)?.group(1);
      if (name == null || rid == null) continue;
      final target = idToTarget[rid];
      if (target == null) continue;
      final cleaned = target.replaceFirst(RegExp(r'^\./'), '');
      final path = cleaned.startsWith('/')
          ? cleaned.substring(1)
          : cleaned.startsWith('xl/')
          ? cleaned
          : 'xl/$cleaned';
      sheets.add(_XlsxSheetRef(name: _xmlUnescape(name), path: path));
    }
    return sheets;
  }

  List<List<String>> _readSheetRows(
    Archive archive,
    String path,
    List<String> sharedStrings,
  ) {
    final file = _findFile(archive, path);
    if (file == null) {
      throw FormatException('No se encontró la hoja $path');
    }
    final xml = utf8.decode(file.content);
    final rowRe = RegExp(r'<row\b[^>]*>(.*?)</row>', dotAll: true);
    final cellRe = RegExp(r'<c\b([^>/]*)(?:/>|>(.*?)</c>)', dotAll: true);

    final rows = <List<String>>[];
    for (final rowMatch in rowRe.allMatches(xml)) {
      final rowXml = rowMatch.group(1) ?? '';
      final cellsByCol = <int, String>{};
      var maxCol = -1;

      for (final cellMatch in cellRe.allMatches(rowXml)) {
        final attrs = cellMatch.group(1) ?? '';
        final inner = cellMatch.group(2) ?? '';
        final refMatch = RegExp(r'\br="([A-Za-z]+)(\d+)"').firstMatch(attrs);
        final col = refMatch != null
            ? _colIndex(refMatch.group(1)!.toUpperCase())
            : maxCol + 1;
        maxCol = col > maxCol ? col : maxCol;

        final typeMatch = RegExp(r'\bt="([^"]+)"').firstMatch(attrs);
        final type = typeMatch?.group(1);

        String value = '';
        if (type == 'inlineStr') {
          final tMatch = RegExp(
            r'<t(?:\s[^>]*)?>(.*?)</t>',
            dotAll: true,
          ).firstMatch(inner);
          value = _xmlUnescape(tMatch?.group(1) ?? '');
        } else if (type == 's') {
          final vMatch = RegExp(r'<v>(.*?)</v>').firstMatch(inner);
          final idx = int.tryParse(vMatch?.group(1) ?? '') ?? -1;
          value = (idx >= 0 && idx < sharedStrings.length)
              ? sharedStrings[idx]
              : '';
        } else if (type == 'str' || type == 'b') {
          final vMatch = RegExp(r'<v>(.*?)</v>').firstMatch(inner);
          value = _xmlUnescape(vMatch?.group(1) ?? '');
        } else {
          final vMatch = RegExp(r'<v>(.*?)</v>').firstMatch(inner);
          value = vMatch?.group(1) ?? '';
        }
        cellsByCol[col] = value;
      }

      if (maxCol < 0) {
        rows.add(const []);
        continue;
      }
      final row = List<String>.generate(maxCol + 1, (i) => cellsByCol[i] ?? '');
      rows.add(row);
    }
    return rows;
  }

  int _colIndex(String letters) {
    var n = 0;
    for (final cu in letters.codeUnits) {
      n = n * 26 + (cu - 64);
    }
    return n - 1;
  }

  String _xmlUnescape(String s) => s
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&');

  ArchiveFile? _findFile(Archive archive, String path) {
    final normalized = path
        .replaceAll('\\', '/')
        .replaceFirst(RegExp(r'^/'), '');
    for (final f in archive.files) {
      final name = f.name.replaceAll('\\', '/').replaceFirst(RegExp(r'^/'), '');
      if (name == normalized) return f;
    }
    return null;
  }
}

class _XlsxSheetRef {
  final String name;
  final String path;
  const _XlsxSheetRef({required this.name, required this.path});
}
