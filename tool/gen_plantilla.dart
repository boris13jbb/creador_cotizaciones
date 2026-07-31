// ignore_for_file: avoid_print
// Ejecutar desde raíz del proyecto: dart run tool/gen_plantilla.dart
// Genera assets/plantilla.docx con content controls para CotiApp.

import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';

const wNs = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';
const rNs = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships';

// XML compacto sin espacios entre elementos (evita XmlText que rompe docx_template_fork)
String sdtText(String alias, String placeholder) {
  return '<w:sdt xmlns:w="$wNs"><w:sdtPr><w:alias w:val="$alias"/><w:tag w:val="text"/><w:id w:val="${alias.hashCode & 0x7FFFFFFF}"/></w:sdtPr><w:sdtContent><w:p><w:r><w:t xml:space="preserve">$placeholder</w:t></w:r></w:p></w:sdtContent></w:sdt>';
}

String sdtList(String alias, String itemAlias, String itemPlaceholder) {
  return '<w:sdt xmlns:w="$wNs"><w:sdtPr><w:alias w:val="$alias"/><w:tag w:val="list"/><w:id w:val="${alias.hashCode & 0x7FFFFFFF}"/></w:sdtPr><w:sdtContent><w:p><w:sdt><w:sdtPr><w:alias w:val="$itemAlias"/><w:tag w:val="text"/><w:id w:val="${itemAlias.hashCode & 0x7FFFFFFF}"/></w:sdtPr><w:sdtContent><w:r><w:t xml:space="preserve">$itemPlaceholder</w:t></w:r></w:sdtContent></w:sdt></w:p></w:sdtContent></w:sdt>';
}

String sdtTableRow(String rowAlias, String cell1Alias, String cell2Alias, String cell3Alias) {
  return '<w:sdt xmlns:w="$wNs"><w:sdtPr><w:alias w:val="$rowAlias"/><w:tag w:val="table"/><w:id w:val="${rowAlias.hashCode & 0x7FFFFFFF}"/></w:sdtPr><w:sdtContent><w:tr><w:tc><w:p><w:sdt><w:sdtPr><w:alias w:val="$cell1Alias"/><w:tag w:val="text"/><w:id w:val="${cell1Alias.hashCode & 0x7FFFFFFF}"/></w:sdtPr><w:sdtContent><w:p><w:r><w:t>---</w:t></w:r></w:p></w:sdtContent></w:sdt></w:p></w:tc><w:tc><w:p><w:sdt><w:sdtPr><w:alias w:val="$cell2Alias"/><w:tag w:val="text"/><w:id w:val="${cell2Alias.hashCode & 0x7FFFFFFF}"/></w:sdtPr><w:sdtContent><w:p><w:r><w:t>---</w:t></w:r></w:p></w:sdtContent></w:sdt></w:p></w:tc><w:tc><w:p><w:sdt><w:sdtPr><w:alias w:val="$cell3Alias"/><w:tag w:val="text"/><w:id w:val="${cell3Alias.hashCode & 0x7FFFFFFF}"/></w:sdtPr><w:sdtContent><w:p><w:r><w:t>---</w:t></w:r></w:p></w:sdtContent></w:sdt></w:p></w:tc></w:tr></w:sdtContent></w:sdt>';
}

void main() {
  // XML compacto: sin espacios entre elementos para evitar nodos XmlText que rompen docx_template_fork
  final documentBody = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:document xmlns:w="$wNs"><w:body><w:p><w:r><w:t>COTIZACIÓN DE SERVICIOS</w:t></w:r></w:p><w:p><w:r><w:t>Número: </w:t></w:r>${sdtText('numero', 'COT-2026-001')}</w:p><w:p><w:r><w:t>Fecha: </w:t></w:r>${sdtText('fecha', 'Marzo 2026')}</w:p><w:p><w:r><w:t>Cliente: </w:t></w:r>${sdtText('cliente', 'Nombre del cliente')}</w:p><w:p><w:r><w:t>Ubicación: </w:t></w:r>${sdtText('ubicacion', 'Ecuador')}</w:p><w:p><w:r><w:t>Tipo de servicio: </w:t></w:r>${sdtText('tipoServicio', 'Soporte técnico')}</w:p><w:p><w:r><w:t>Cantidad equipos: </w:t></w:r>${sdtText('cantidadEquipos', '26 computadoras')}</w:p><w:p><w:r><w:t>Tiempo estimado: </w:t></w:r>${sdtText('tiempoEstimado', '2 – 4 horas')}</w:p><w:p><w:r><w:t>Descripción: </w:t></w:r>${sdtText('descripcion', 'Descripción del servicio...')}</w:p><w:p><w:r><w:t>Total: </w:t></w:r>${sdtText('total', '\$180.00')}</w:p><w:p><w:r><w:t>DETALLE DE SERVICIOS</w:t></w:r></w:p><w:tbl><w:tr><w:tc><w:p><w:r><w:t>Módulo / Servicio</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>Descripción</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>Precio (USD)</w:t></w:r></w:p></w:tc></w:tr>${sdtTableRow('servicios', 'nombreServicio', 'descripcionServicio', 'precioServicio')}</w:tbl><w:p><w:r><w:t>INCLUYE</w:t></w:r></w:p>${sdtList('listaIncluye', 'itemIncluye', 'Revisión técnica...')}<w:p><w:r><w:t>NO INCLUYE</w:t></w:r></w:p>${sdtList('listaNoIncluye', 'itemNoIncluye', 'Reparación de hardware...')}<w:p><w:r><w:t>NOTAS</w:t></w:r></w:p>${sdtList('listaNotas', 'itemNota', 'Cotización válida 30 días')}<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/></w:sectPr></w:body></w:document>';

  final docFixed = documentBody;

  final contentTypes = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
</Types>''';

  final rels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>''';

  final wordRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''';

  final core = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties">
  <dc:title xmlns:dc="http://purl.org/dc/elements/1.1/">CotiApp Plantilla</dc:title>
  <dc:creator>CotiApp</dc:creator>
</cp:coreProperties>''';

  final app = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties">
  <Application>CotiApp</Application>
</Properties>''';

  final styles = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="$wNs">
  <w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/><w:sz w:val="22"/></w:rPr></w:rPrDefault></w:docDefaults>
</w:styles>''';

  final archive = Archive();
  void add(String path, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  add('[Content_Types].xml', contentTypes);
  add('_rels/.rels', rels);
  add('word/_rels/document.xml.rels', wordRels);
  add('word/document.xml', docFixed);
  add('word/styles.xml', styles);
  add('docProps/core.xml', core);
  add('docProps/app.xml', app);

  final outPath = 'assets/plantilla.docx';
  File(outPath).parent.createSync(recursive: true);
  final encoded = ZipEncoder().encode(archive);
  // if (encoded != null) { // La comparación con null es innecesaria, ya que encoded nunca será null
    File(outPath).writeAsBytesSync(encoded);
  // }
  print('Generado: $outPath');
}
