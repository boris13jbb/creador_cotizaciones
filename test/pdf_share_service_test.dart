import 'dart:typed_data';

import 'package:creador_cotizaciones/core/utils/money_cents.dart';
import 'package:creador_cotizaciones/saas/domain/org_enums.dart';
import 'package:creador_cotizaciones/saas/domain/quote_totals.dart';
import 'package:creador_cotizaciones/saas/models/quote.dart';
import 'package:creador_cotizaciones/saas/services/quote_share_service.dart';
import 'package:creador_cotizaciones/services/pdf_service.dart';
import 'package:creador_cotizaciones/services/pdf_share_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:universal_io/io.dart';

Uint8List _minimalPdfBytes() {
  final content =
      '%PDF-1.4\n'
      '1 0 obj<<>>endobj\n'
      'trailer<<>>\n'
      '%%EOF\n';
  return Uint8List.fromList(content.codeUnits);
}

Quote _sampleQuote({required String id, required String orgId}) {
  final now = DateTime.utc(2026, 3, 1);
  return Quote(
    id: id,
    organizationId: orgId,
    number: 'COT-SHARE-1',
    sequence: 1,
    clientName: 'Cliente Share',
    issueDate: now,
    items: [
      QuoteLineItem.fromQuantity(
        id: 'i1',
        name: 'Servicio',
        quantity: 1,
        unitPrice: const MoneyCents(5000),
      ),
    ],
    total: const MoneyCents(5000),
    status: QuoteStatus.draft,
    createdByUid: 'uid-share',
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;

  setUp(() async {
    PdfShareService.instance.debugResetBusy();
    tempRoot = await Directory.systemTemp.createTemp('cotiapp_share_test_');
    PdfShareService.instance.debugTempRoot = tempRoot;
  });

  tearDown(() async {
    PdfShareService.instance.debugResetBusy();
    PdfShareService.instance.debugTempRoot = null;
    try {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    } catch (_) {}
  });

  test('looksLikePdf acepta cabecera %PDF- y rechaza vacío/basura', () {
    expect(PdfShareService.looksLikePdf(_minimalPdfBytes()), isTrue);
    expect(PdfShareService.looksLikePdf(Uint8List(0)), isFalse);
    expect(
      PdfShareService.looksLikePdf(Uint8List.fromList([1, 2, 3, 4, 5])),
      isFalse,
    );
  });

  test('safeFileName sanitiza el número de cotización', () {
    expect(
      PdfShareService.safeFileName('COT/2026 #1'),
      'Cotizacion_COT_2026_1.pdf',
    );
    expect(PdfShareService.safeFileName(''), 'Cotizacion_cotizacion.pdf');
  });

  test('prepareTempPdf escribe archivo no vacío y válido', () async {
    final prepared = await PdfShareService.instance.prepareTempPdf(
      bytes: _minimalPdfBytes(),
      number: 'COT-1',
    );
    final file = File(prepared.filePath);
    expect(await file.exists(), isTrue);
    expect(prepared.byteLength, greaterThan(0));
    expect(prepared.fileName, endsWith('.pdf'));
    final read = await file.readAsBytes();
    expect(PdfShareService.looksLikePdf(Uint8List.fromList(read)), isTrue);
  });

  test('prepareTempPdf falla con bytes vacíos o inválidos', () async {
    expect(
      () => PdfShareService.instance.prepareTempPdf(
        bytes: Uint8List(0),
        number: 'X',
      ),
      throwsA(
        isA<StateError>().having((e) => e.message, 'msg', 'share_pdf_empty'),
      ),
    );
    expect(
      () => PdfShareService.instance.prepareTempPdf(
        bytes: Uint8List.fromList([0, 1, 2, 3, 4, 5]),
        number: 'X',
      ),
      throwsA(
        isA<StateError>().having((e) => e.message, 'msg', 'share_pdf_invalid'),
      ),
    );
  });

  test('anti doble-pulsación: busy bloquea segunda llamada', () async {
    final svc = PdfShareService.instance;
    svc.debugSetBusy(true);
    expect(
      () => svc.sharePdfBytes(bytes: _minimalPdfBytes(), number: 'BUSY-1'),
      throwsA(
        isA<StateError>().having((e) => e.message, 'msg', 'share_pdf_busy'),
      ),
    );
    svc.debugSetBusy(false);
  });

  test('PdfService genera PDF compartible (cabecera válida)', () async {
    final quote = _sampleQuote(id: 'q-share-gen', orgId: 'org-share');
    final bytes = await PdfService.generarPDFFromQuote(
      quote,
      languageCode: 'es',
    );
    expect(bytes, isNotEmpty);
    expect(PdfShareService.looksLikePdf(bytes), isTrue);
    final prepared = await PdfShareService.instance.prepareTempPdf(
      bytes: bytes,
      number: quote.number,
    );
    expect(prepared.byteLength, bytes.length);
  });

  test('mensaje de share no exige URL', () {
    final msg = QuoteShareService.instance.buildShareMessage(
      number: 'COT-9',
      clientName: 'Ana',
      totalLabel: r'$10.00',
    );
    expect(msg, contains('COT-9'));
    expect(msg, isNot(contains('Ver detalle:')));

    final withUrl = QuoteShareService.instance.buildShareMessage(
      number: 'COT-9',
      clientName: 'Ana',
      totalLabel: r'$10.00',
      shareUrl: 'https://example.com/t',
    );
    expect(withUrl, contains('Ver detalle:'));
  });

  test(
    'preparar PDF solo escribe bajo cotiapp_share (no toca SQLite app)',
    () async {
      final quote = _sampleQuote(id: 'q-local-keep', orgId: 'org-share-q');
      final bytes = await PdfService.generarPDFFromQuote(
        quote,
        languageCode: 'es',
      );
      final beforeEntities = tempRoot.listSync(recursive: true).length;
      final prepared = await PdfShareService.instance.prepareTempPdf(
        bytes: bytes,
        number: quote.number,
      );
      expect(File(prepared.filePath).path.contains('cotiapp_share'), isTrue);
      expect(p.isWithin(tempRoot.path, prepared.filePath), isTrue);
      final afterEntities = tempRoot.listSync(recursive: true).length;
      expect(afterEntities, greaterThan(beforeEntities));
      // El servicio de share no usa OfflineLocalStore / sync_queue.
      expect(PdfShareService.instance.isBusy, isFalse);
    },
  );

  test(
    'tryCreateShareLink sin quote/uid devuelve null (offline-safe)',
    () async {
      final r = await QuoteShareService.instance.tryCreateShareLink(
        quote: null,
        createdByUid: '',
      );
      expect(r, isNull);
    },
  );

  test(
    'archivo preparado vive bajo directorio temporal cotiapp_share',
    () async {
      final prepared = await PdfShareService.instance.prepareTempPdf(
        bytes: _minimalPdfBytes(),
        number: 'PATH-1',
      );
      expect(p.basename(p.dirname(prepared.filePath)), 'cotiapp_share');
    },
  );
}
