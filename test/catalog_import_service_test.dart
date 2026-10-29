import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:creador_cotizaciones/core/utils/money_cents.dart';
import 'package:creador_cotizaciones/saas/domain/org_enums.dart';
import 'package:creador_cotizaciones/saas/models/catalog_item.dart';
import 'package:creador_cotizaciones/saas/services/catalog_import/catalog_csv_codec.dart';
import 'package:creador_cotizaciones/saas/services/catalog_import/catalog_import_models.dart';
import 'package:creador_cotizaciones/saas/services/catalog_import/catalog_import_service.dart';
import 'package:creador_cotizaciones/saas/services/catalog_import/catalog_xlsx_codec.dart';
import 'package:flutter_test/flutter_test.dart';

CatalogItem _item({
  required String id,
  required String code,
  required String name,
}) {
  final now = DateTime.utc(2024, 1, 1);
  return CatalogItem(
    id: id,
    organizationId: 'org1',
    code: code,
    name: name,
    unitPrice: const MoneyCents(1000),
    status: CatalogItemStatus.active,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late CatalogImportService service;

  setUp(() {
    service = CatalogImportService();
  });

  group('plantilla Excel OOXML', () {
    test('genera ZIP válido con Instrucciones, Productos y sharedStrings', () {
      final bytes = CatalogXlsxCodec.instance.buildTemplate(
        spanishLabels: true,
      );
      expect(bytes.length, greaterThan(100));
      expect(bytes[0], 0x50);
      expect(bytes[1], 0x4b);
      // Excel Desktop falla con bit UTF-8 en ZIP de rutas ASCII.
      expect((bytes[6] | (bytes[7] << 8)) & 2048, 0);

      final archive = ZipDecoder().decodeBytes(bytes, verify: false);
      expect(archive.findFile('[Content_Types].xml'), isNotNull);
      expect(archive.findFile('xl/sharedStrings.xml'), isNotNull);
      expect(archive.findFile('xl/styles.xml'), isNotNull);
      expect(archive.findFile('xl/worksheets/sheet1.xml'), isNotNull);
      expect(archive.findFile('xl/worksheets/sheet2.xml'), isNotNull);

      final styles = utf8.decode(archive.findFile('xl/styles.xml')!.content);
      expect(styles, contains('gray125'));
      expect(styles, contains('numFmtId'));

      final wb = utf8.decode(archive.findFile('xl/workbook.xml')!.content);
      expect(wb, contains('Instrucciones'));
      expect(wb, contains('Productos'));
      expect(wb, contains('defaultThemeVersion'));
      expect(wb, contains('calcPr'));
    });

    test('roundtrip: generar y volver a leer encabezados y ejemplos', () {
      final bytes = CatalogXlsxCodec.instance.buildTemplate(
        spanishLabels: true,
      );
      final table = CatalogXlsxCodec.instance.decodeBytes(bytes);
      expect(table, isNotEmpty);
      expect(
        table.first,
        equals([
          'code',
          'name',
          'description',
          'category',
          'unit',
          'unitPrice',
          'taxPercent',
        ]),
      );
      expect(table.length, greaterThanOrEqualTo(3));
      expect(table[1][0], startsWith('EJEMPLO'));
      expect(table[2][1], contains('ñ'));

      final a = service.analyzeBytes(
        bytes: bytes,
        fileName: 'plantilla.xlsx',
        organizationId: 'org1',
        existingItems: const [],
      );
      expect(a.hasBlockingGlobalIssues, isFalse);
      expect(a.exampleRows.length, greaterThanOrEqualTo(2));
      expect(a.validRows, isEmpty);
    });

    test('importa dos productos reales tras la plantilla Excel', () {
      final template = CatalogXlsxCodec.instance.decodeBytes(
        CatalogXlsxCodec.instance.buildTemplate(spanishLabels: true),
      );
      final rows = <List<String>>[
        template.first,
        ...template.skip(1),
        [
          'P-100',
          'Producto Alfa',
          'Desc con ñ',
          'Categoría',
          'und',
          '25.5',
          '12',
        ],
        ['P-200', 'Producto Beta', 'Segundo', 'General', 'hrs', '100', '0'],
      ];
      // Reconstruir xlsx no hace falta: analyzeTable cubre el contrato.
      final a = service.analyzeTable(
        table: rows,
        fileName: 'filled.xlsx',
        organizationId: 'org1',
        existingItems: const [],
      );
      expect(a.exampleRows.length, greaterThanOrEqualTo(2));
      expect(a.validRows, hasLength(2));
      expect(a.validRows[0].name, 'Producto Alfa');
      expect(a.validRows[0].unitPrice, closeTo(25.5, 0.001));
      expect(a.validRows[0].category, 'Categoría');
      expect(a.validRows[1].code, 'P-200');
      expect(a.validRows[1].unit, 'hrs');
    });

    test('lee celdas numéricas como las escribe Excel (shared + <v>)', () {
      // Simula hoja Productos guardada por Excel: sharedStrings + números.
      final archive = Archive();
      void add(String path, String xml) {
        final data = utf8.encode(xml);
        archive.addFile(ArchiveFile.bytes(path, data));
      }

      add('[Content_Types].xml', '''<?xml version="1.0" encoding="UTF-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>
</Types>''');
      add('_rels/.rels', '''<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>''');
      add('xl/workbook.xml', '''<?xml version="1.0" encoding="UTF-8"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets><sheet name="Productos" sheetId="1" r:id="rId1"/></sheets>
</workbook>''');
      add(
        'xl/_rels/workbook.xml.rels',
        '''<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>
</Relationships>''',
      );
      add('xl/sharedStrings.xml', '''<?xml version="1.0" encoding="UTF-8"?>
<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="11" uniqueCount="11">
  <si><t>code</t></si><si><t>name</t></si><si><t>description</t></si>
  <si><t>category</t></si><si><t>unit</t></si><si><t>unitPrice</t></si>
  <si><t>taxPercent</t></si><si><t>SKU-9</t></si><si><t>Nombre ñ</t></si>
  <si><t>General</t></si><si><t>und</t></si>
</sst>''');
      add('xl/worksheets/sheet1.xml', '''<?xml version="1.0" encoding="UTF-8"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetData>
    <row r="1">
      <c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c>
      <c r="C1" t="s"><v>2</v></c><c r="D1" t="s"><v>3</v></c>
      <c r="E1" t="s"><v>4</v></c><c r="F1" t="s"><v>5</v></c>
      <c r="G1" t="s"><v>6</v></c>
    </row>
    <row r="2">
      <c r="A2" t="s"><v>7</v></c><c r="B2" t="s"><v>8</v></c>
      <c r="C2" t="s"><v>2</v></c><c r="D2" t="s"><v>9</v></c>
      <c r="E2" t="s"><v>10</v></c>
      <c r="F2"><v>33.5</v></c><c r="G2"><v>12</v></c>
    </row>
  </sheetData>
</worksheet>''');

      final bytes = ZipEncoder().encode(archive);
      final a = service.analyzeBytes(
        bytes: bytes,
        fileName: 'excel_saved.xlsx',
        organizationId: 'org1',
        existingItems: const [],
      );
      expect(a.hasBlockingGlobalIssues, isFalse);
      expect(a.validRows, hasLength(1));
      expect(a.validRows.single.name, 'Nombre ñ');
      expect(a.validRows.single.unitPrice, closeTo(33.5, 0.001));
      expect(a.validRows.single.taxPercent, 12);
    });
  });

  group('CSV', () {
    test('plantilla CSV usa cabeceras canónicas y BOM UTF-8', () {
      final text = CatalogCsvCodec.instance.buildTemplate(spanishLabels: true);
      expect(text.startsWith('\uFEFF'), isTrue);
      expect(text, contains(CatalogCsvCodec.templateHeader));
      final table = CatalogCsvCodec.instance.decodeBytes(utf8.encode(text));
      expect(
        table.first,
        equals([
          'code',
          'name',
          'description',
          'category',
          'unit',
          'unitPrice',
          'taxPercent',
        ]),
      );
    });

    test('lee CSV con tildes, eñes, comas y comillas', () {
      const csv = '''
codigo,nombre,descripcion,categoria,unidad,precio,impuesto
SKU-1,"Producto ñandú","Desc, con ""comillas""",Categoría,und,"12,50",12
''';
      final a = service.analyzeCsvText(csv: csv, organizationId: 'org1');
      expect(a.hasBlockingGlobalIssues, isFalse);
      expect(a.validRows, hasLength(1));
      final row = a.validRows.single;
      expect(row.name, 'Producto ñandú');
      expect(row.description, 'Desc, con "comillas"');
      expect(row.category, 'Categoría');
      expect(row.unitPrice, closeTo(12.5, 0.001));
      expect(row.taxPercent, 12);
    });

    test('importa dos productos reales desde CSV', () {
      final template = CatalogCsvCodec.instance.buildTemplate(
        spanishLabels: true,
      );
      final csv =
          '$template'
          'R1,Producto Uno,Desc 1,Cat A,und,10.5,0\r\n'
          'R2,Producto Dos,Desc 2,Cat B,hrs,20,12\r\n';
      final a = service.analyzeBytes(
        bytes: utf8.encode(csv),
        fileName: 'filled.csv',
        organizationId: 'org1',
        existingItems: const [],
      );
      expect(a.exampleRows.length, greaterThanOrEqualTo(2));
      expect(a.validRows, hasLength(2));
      expect(a.validRows.map((r) => r.name), ['Producto Uno', 'Producto Dos']);
    });

    test('rechaza archivo vacío', () {
      final a = service.analyzeCsvText(csv: '', organizationId: 'org1');
      expect(a.hasBlockingGlobalIssues, isTrue);
      expect(
        a.globalIssues.any((i) => i.kind == CatalogImportIssueKind.emptyFile),
        isTrue,
      );
    });

    test('rechaza cabecera sin nombre', () {
      const csv = 'codigo,precio\nA,10\n';
      final a = service.analyzeCsvText(csv: csv, organizationId: 'org1');
      expect(
        a.globalIssues.any(
          (i) => i.kind == CatalogImportIssueKind.missingNameHeader,
        ),
        isTrue,
      );
    });

    test('marca cabeceras desconocidas sin bloquear', () {
      const csv = 'name,foo,unitPrice\nItem,x,5\n';
      final a = service.analyzeCsvText(csv: csv, organizationId: 'org1');
      expect(a.hasBlockingGlobalIssues, isFalse);
      expect(a.unrecognizedHeaders, contains('foo'));
      expect(a.validRows, hasLength(1));
    });

    test('rechaza precios negativos e inválidos', () {
      const csv = '''
name,unitPrice
Ok,10
Bad,-1
Worse,abc
''';
      final a = service.analyzeCsvText(csv: csv, organizationId: 'org1');
      expect(a.validRows, hasLength(1));
      expect(a.errorRows, hasLength(2));
      expect(
        a.errorRows.any(
          (r) => r.issues.any(
            (i) => i.kind == CatalogImportIssueKind.negativePrice,
          ),
        ),
        isTrue,
      );
      expect(
        a.errorRows.any(
          (r) => r.issues.any(
            (i) => i.kind == CatalogImportIssueKind.invalidPrice,
          ),
        ),
        isTrue,
      );
    });

    test('omite filas de ejemplo EJEMPLO/EXAMPLE con marcador', () {
      final template = CatalogCsvCodec.instance.buildTemplate(
        spanishLabels: true,
      );
      final csv =
          '${template}SKU-REAL,Producto real,Desc,General,und,9.99,0\r\n';
      final a = service.analyzeBytes(
        bytes: utf8.encode(csv),
        fileName: 't.csv',
        organizationId: 'org1',
        existingItems: const [],
      );
      expect(a.exampleRows.length, greaterThanOrEqualTo(2));
      expect(a.validRows.single.name, 'Producto real');
    });

    test('importa productos reales aunque el código empiece por EJEMPLO', () {
      const csv = '''
code,name,description,category,unit,unitPrice,taxPercent
EJEMPLO-RED,Cableado estructurado,Instalación de red LAN,Servicios,und,120,12
EJEMPLO-CCTV,Cámaras IP,"Kit 4 cámaras, NVR",Seguridad,kit,450,12
''';
      final a = service.analyzeCsvText(
        csv: csv,
        organizationId: 'org1',
        existingItems: const [],
      );
      expect(a.exampleRows, isEmpty);
      expect(a.validRows, hasLength(2));
      expect(a.validRows.map((r) => r.name), [
        'Cableado estructurado',
        'Cámaras IP',
      ]);
      expect(a.hasBlockingGlobalIssues, isFalse);
    });

    test('solo ejemplos de plantilla: sin válidos y aviso onlyExamples', () {
      final template = CatalogCsvCodec.instance.buildTemplate(
        spanishLabels: true,
      );
      final a = service.analyzeBytes(
        bytes: utf8.encode(template),
        fileName: 'solo_ejemplos.csv',
        organizationId: 'org1',
        existingItems: const [],
      );
      expect(a.validRows, isEmpty);
      expect(a.exampleRows.length, greaterThanOrEqualTo(2));
      expect(a.hasBlockingGlobalIssues, isFalse);
      expect(
        a.globalIssues.any(
          (i) => i.kind == CatalogImportIssueKind.onlyExamples,
        ),
        isTrue,
      );
    });

    test('detecta duplicados internos y con catálogo existente por código', () {
      const csv = '''
code,name,unitPrice
ABC,Uno,10
ABC,Dos,20
XYZ,Tres,30
''';
      final existing = [_item(id: 'e1', code: 'XYZ', name: 'Viejo')];
      final a = service.analyzeCsvText(
        csv: csv,
        organizationId: 'org1',
        existingItems: existing,
      );
      expect(a.errorRows.where((r) => r.name == 'Dos'), hasLength(1));
      expect(
        a.rows.where((r) => r.name == 'Tres').single.matchedExistingId,
        'e1',
      );
      expect(a.duplicateRows.any((r) => r.name == 'Tres'), isTrue);
    });

    test('rechaza extensión no soportada (.xls)', () {
      final a = service.analyzeBytes(
        bytes: [1, 2, 3],
        fileName: 'old.xls',
        organizationId: 'org1',
        existingItems: const [],
      );
      expect(
        a.globalIssues.any(
          (i) => i.kind == CatalogImportIssueKind.unsupportedFormat,
        ),
        isTrue,
      );
    });
  });

  group('confirmación y cancelación', () {
    test('buildCommitPlan no escribe; skip omite duplicados existentes', () {
      const csv = '''
code,name,unitPrice
NEW,Nuevo,5
OLD,Actualizar,8
''';
      final existing = [_item(id: 'id-old', code: 'OLD', name: 'Anterior')];
      final a = service.analyzeCsvText(
        csv: csv,
        organizationId: 'org1',
        existingItems: existing,
      );

      final skipPlans = service.buildCommitPlan(
        analysis: a,
        organizationId: 'org1',
        policy: CatalogDuplicatePolicy.skip,
      );
      expect(skipPlans, hasLength(1));
      expect(skipPlans.single.item.name, 'Nuevo');

      final updatePlans = service.buildCommitPlan(
        analysis: a,
        organizationId: 'org1',
        policy: CatalogDuplicatePolicy.updateByCode,
        existingItems: existing,
      );
      expect(updatePlans, hasLength(2));
      final updated = updatePlans.firstWhere((p) => p.isUpdate);
      expect(updated.item.id, 'id-old');
      expect(updated.item.name, 'Actualizar');
      expect(updated.item.createdAt, existing.first.createdAt);
    });

    test('commit con upsertOverride persiste y reporta parcial', () async {
      const csv = 'name,unitPrice\nA,1\nB,2\n';
      final a = service.analyzeCsvText(csv: csv, organizationId: 'org1');
      var calls = 0;
      final result = await service.commit(
        analysis: a,
        organizationId: 'org1',
        policy: CatalogDuplicatePolicy.skip,
        upsertOverride: ({required organizationId, required item}) async {
          calls++;
          if (item.name == 'B') throw Exception('fallo B');
          return item;
        },
      );
      expect(calls, 2);
      expect(result.created, 1);
      expect(result.hasPartialFailures, isTrue);
      expect(result.failures, hasLength(1));
    });

    test('cancelación: sin commit no hay escrituras', () {
      const csv = 'name,unitPrice\nSolo,1\n';
      final a = service.analyzeCsvText(csv: csv, organizationId: 'org1');
      expect(a.validRows, hasLength(1));
      expect(a.validRows.single.name, 'Solo');
    });
  });

  group('límites', () {
    test('archivo demasiado grande', () {
      final bytes = List<int>.filled(CatalogImportService.maxFileBytes + 1, 0);
      final a = service.analyzeBytes(
        bytes: bytes,
        fileName: 'big.csv',
        organizationId: 'org1',
        existingItems: const [],
      );
      expect(
        a.globalIssues.any(
          (i) => i.kind == CatalogImportIssueKind.fileTooLarge,
        ),
        isTrue,
      );
    });
  });

  group('regresión plantilla vs importador', () {
    test('plantilla Excel generada se analiza sin bloqueo', () {
      final bytes = CatalogXlsxCodec.instance.buildTemplate(
        spanishLabels: false,
      );
      Directory('tmp_catalog_diag').createSync(recursive: true);
      File('tmp_catalog_diag/plantilla_fixed.xlsx').writeAsBytesSync(bytes);

      final a = service.analyzeBytes(
        bytes: bytes,
        fileName: 'cotiapp_catalog_template.xlsx',
        organizationId: 'org1',
        existingItems: const [],
      );
      expect(a.hasBlockingGlobalIssues, isFalse, reason: '${a.globalIssues}');
      expect(a.exampleRows, isNotEmpty);
    });
  });
}
