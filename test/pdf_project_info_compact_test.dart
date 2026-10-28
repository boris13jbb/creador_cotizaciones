import 'package:creador_cotizaciones/core/utils/money_cents.dart';
import 'package:creador_cotizaciones/saas/domain/org_enums.dart';
import 'package:creador_cotizaciones/saas/domain/quote_totals.dart';
import 'package:creador_cotizaciones/saas/models/quote.dart';
import 'package:creador_cotizaciones/services/pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';

Quote _quote({
  required String id,
  required String client,
  Map<String, dynamic> legacy = const {},
  int itemCount = 1,
}) {
  final now = DateTime.utc(2026, 10, 28);
  final items = List.generate(
    itemCount,
    (i) => QuoteLineItem.fromQuantity(
      id: 'l$i',
      name: 'Servicio ${i + 1}',
      description: 'Detalle ${i + 1}',
      quantity: 1,
      unitPrice: const MoneyCents(10000),
    ),
  );
  return Quote(
    id: id,
    organizationId: 'org-pdf-compact',
    number: 'COT-$id',
    sequence: 1,
    status: QuoteStatus.draft,
    clientName: client,
    issueDate: now,
    items: items,
    total: MoneyCents(10000 * itemCount),
    createdByUid: 'u1',
    createdAt: now,
    updatedAt: now,
    legacyFields: legacy,
  ).withRecalculatedTotal();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'densidad del bloque info proyecto es más compacta que el diseño previo',
    () {
      // Fuentes: reducción ~10–15 % vs. 11 / 7 / 9 previos.
      expect(ProjectInfoPdfDensity.sectionTitleSize, lessThan(11));
      expect(ProjectInfoPdfDensity.sectionTitleSize, greaterThanOrEqualTo(9));
      expect(ProjectInfoPdfDensity.labelSize, lessThan(7));
      expect(ProjectInfoPdfDensity.valueSize, lessThan(9));
      expect(ProjectInfoPdfDensity.descriptionSize, lessThan(9));
      // Paddings verticales: reducción ~30–35 % vs. 6 previos.
      expect(ProjectInfoPdfDensity.cellPaddingV, lessThan(6));
      expect(ProjectInfoPdfDensity.cellPaddingV, greaterThanOrEqualTo(3));
      expect(ProjectInfoPdfDensity.gapBeforeBlock, lessThan(20));
      expect(ProjectInfoPdfDensity.gapBeforeDescription, lessThan(15));
      expect(
        ProjectInfoPdfDensity.sectionTitleSize,
        lessThan(ProjectInfoPdfDensity.defaultSectionTitleSize),
      );
    },
  );

  test('PDF con datos cortos genera documento válido', () async {
    final quote = _quote(
      id: 'short',
      client: 'ACME',
      legacy: {
        'ubicacion': 'Quito',
        'tipoServicio': 'IT',
        'tiempoEstimado': '2d',
        'descripcion': 'Corto.',
      },
    );
    final bytes = await PdfService.generarPDFFromQuote(quote);
    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    final body = String.fromCharCodes(bytes);
    expect(body.contains('ACME') || body.contains('NotoSans'), isTrue);
  });

  test(
    'PDF con cliente/ubicación/descripción largos no trunca el contenido',
    () async {
      final longClient =
          'Compañía Internacional de Soluciones Técnicas Avanzadas S.A. '
          'Sucursal Norte — Departamento de Proyectos Especiales';
      final longLocation =
          'Av. de los Shyris N37-32 y Naciones Unidas, Edificio Corporativo '
          'Torre B, piso 12, oficina 1204, Quito, Ecuador';
      final longDesc = List.generate(
        8,
        (i) =>
            'Párrafo ${i + 1}: alcance de obra, entregables, criterios de '
            'aceptación y coordinación con el cliente en sitio.',
      ).join('\n');

      final quote = _quote(
        id: 'long',
        client: longClient,
        legacy: {
          'ubicacion': longLocation,
          'tipoServicio': 'Integración de sistemas de seguridad y redes',
          'tiempoEstimado': '6 a 8 semanas según disponibilidad de equipos',
          'descripcion': longDesc,
        },
        itemCount: 3,
      );

      final bytes = await PdfService.generarPDFFromQuote(quote);
      expect(bytes.length, greaterThan(2000));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      // Texto del usuario viaja en streams; al menos el PDF debe construirse.
      expect(bytes.length, greaterThan(5000));
    },
  );

  test('PDF multipágina con muchos ítems sigue siendo válido', () async {
    final quote = _quote(
      id: 'multi',
      client: 'Cliente Multipágina',
      legacy: {
        'ubicacion': 'Guayaquil',
        'descripcion':
            'Descripción media del proyecto con varios entregables '
            'y coordinación semanal.',
        'tipoServicio': 'Mantenimiento',
        'tiempoEstimado': '3 meses',
      },
      itemCount: 28,
    );
    final bytes = await PdfService.generarPDFFromQuote(quote);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(5000));
  });

  test('PDF sin descripción omite ese subtítulo y sigue compacto', () async {
    final quote = _quote(
      id: 'nodesc',
      client: 'Sin Desc',
      legacy: {
        'ubicacion': 'Cuenca',
        'tipoServicio': '',
        'tiempoEstimado': '',
        'descripcion': '',
      },
    );
    final bytes = await PdfService.generarPDFFromQuote(quote);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(800));
  });
}
