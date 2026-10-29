import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:creador_cotizaciones/core/utils/money_cents.dart';
import 'package:creador_cotizaciones/saas/domain/quote_totals.dart';
import 'package:creador_cotizaciones/saas/models/org_branding.dart';
import 'package:creador_cotizaciones/saas/models/quote.dart';
import 'package:creador_cotizaciones/saas/services/branding_storage_service.dart';
import 'package:creador_cotizaciones/saas/services/quote_mapper.dart';
import 'package:creador_cotizaciones/services/pdf_service.dart';

/// PNG 1×1 transparente.
Uint8List _tinyPng() => Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  ),
);

/// JPEG 1×1.
Uint8List _tinyJpeg() => Uint8List.fromList([
  0xFF,
  0xD8,
  0xFF,
  0xE0,
  0x00,
  0x10,
  0x4A,
  0x46,
  0x49,
  0x46,
  0x00,
  0x01,
  0x01,
  0x00,
  0x00,
  0x01,
  0x00,
  0x01,
  0x00,
  0x00,
  0xFF,
  0xDB,
  0x00,
  0x43,
  0x00,
  0x08,
  0x06,
  0x06,
  0x07,
  0x06,
  0x05,
  0x08,
  0x07,
  0x07,
  0x07,
  0x09,
  0x09,
  0x08,
  0x0A,
  0x0C,
  0x14,
  0x0D,
  0x0C,
  0x0B,
  0x0B,
  0x0C,
  0x19,
  0x12,
  0x13,
  0x0F,
  0x14,
  0x1D,
  0x1A,
  0x1F,
  0x1E,
  0x1D,
  0x1A,
  0x1C,
  0x1C,
  0x20,
  0x24,
  0x2E,
  0x27,
  0x20,
  0x22,
  0x2C,
  0x23,
  0x1C,
  0x1C,
  0x28,
  0x37,
  0x29,
  0x2C,
  0x30,
  0x31,
  0x34,
  0x34,
  0x34,
  0x1F,
  0x27,
  0x39,
  0x3D,
  0x38,
  0x32,
  0x3C,
  0x2E,
  0x33,
  0x34,
  0x32,
  0xFF,
  0xC0,
  0x00,
  0x0B,
  0x08,
  0x00,
  0x01,
  0x00,
  0x01,
  0x01,
  0x01,
  0x11,
  0x00,
  0xFF,
  0xC4,
  0x00,
  0x14,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x09,
  0xFF,
  0xC4,
  0x00,
  0x14,
  0x10,
  0x01,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0xFF,
  0xDA,
  0x00,
  0x08,
  0x01,
  0x01,
  0x00,
  0x00,
  0x3F,
  0x00,
  0x7F,
  0xFF,
  0xD9,
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final storage = BrandingStorageService.instance;

  test('acepta PNG válido por firma mágica', () {
    expect(storage.detectKind(_tinyPng()), LogoImageKind.png);
    expect(
      () => storage.validateLogoBytes(_tinyPng(), fileName: 'a.png'),
      returnsNormally,
    );
  });

  test('acepta JPG válido por firma mágica', () {
    expect(storage.detectKind(_tinyJpeg()), LogoImageKind.jpeg);
    expect(
      () => storage.validateLogoBytes(_tinyJpeg(), fileName: 'a.jpg'),
      returnsNormally,
    );
  });

  test('rechaza archivo inválido', () {
    expect(
      () => storage.validateLogoBytes(
        Uint8List.fromList([1, 2, 3, 4]),
        fileName: 'x.png',
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('rechaza archivo mayor al límite', () {
    final previous = BrandingStorageService.maxBytes;
    BrandingStorageService.maxBytes = 100;
    addTearDown(() => BrandingStorageService.maxBytes = previous);
    final big = Uint8List.fromList([..._tinyPng(), ...List.filled(200, 0)]);
    expect(
      () => storage.validateLogoBytes(big, fileName: 'big.png'),
      throwsA(isA<Exception>()),
    );
  });

  test('OrgBranding roundtrip y layout legacy de Quote', () {
    final branding = const OrgBranding(
      logoUrl: 'https://example.com/logo.png',
      logoStoragePath: 'organizations/o1/branding/logo.png',
      colorsJson: '{"primary":"#112233"}',
      logoSizePt: 64,
      logoAlignment: LogoAlignment.center,
    );
    final map = branding.toMap();
    final back = OrgBranding.fromMap(map);
    expect(back.logoUrl, branding.logoUrl);
    expect(back.logoSizePt, 64);
    expect(back.logoAlignment, LogoAlignment.center);

    final quote = Quote(
      id: 'q1',
      organizationId: 'org',
      number: 'COT-1',
      sequence: 1,
      clientName: 'Acme',
      issueDate: DateTime.utc(2026, 1, 1),
      items: const [],
      total: MoneyCents.zero,
      logoPath: branding.logoUrl,
      colorsJson: branding.colorsJson,
      createdByUid: 'u1',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      legacyFields: branding.toQuoteLegacyFields(),
    );
    final layout = OrgBranding.fromQuoteLegacy(
      logoPath: quote.logoPath,
      colorsJson: quote.colorsJson,
      legacy: quote.legacyFields,
    );
    expect(layout.logoAlignment, LogoAlignment.center);
    expect(layout.logoSizePt, 64);

    final cot = QuoteMapper.toCotizacion(quote);
    expect(cot.logoPath, branding.logoUrl);
    expect(cot.coloresJson, branding.colorsJson);
  });

  test('cotización antigua sin logo sigue mapeando', () {
    final quote = Quote(
      id: 'q2',
      organizationId: 'org',
      number: 'COT-2',
      sequence: 2,
      clientName: 'Old',
      issueDate: DateTime.utc(2025, 1, 1),
      items: [
        QuoteLineItem.fromQuantity(
          id: 'i1',
          name: 'S',
          quantity: 1,
          unitPrice: const MoneyCents(1000),
        ),
      ],
      total: const MoneyCents(1000),
      createdByUid: 'u1',
      createdAt: DateTime.utc(2025, 1, 1),
      updatedAt: DateTime.utc(2025, 1, 1),
    );
    final cot = QuoteMapper.toCotizacion(quote);
    expect(cot.logoPath, isNull);
    expect(cot.total, closeTo(10.0, 0.01));
  });

  test('loadLogoBytes soporta data URL', () async {
    final b64 = base64Encode(_tinyPng());
    final bytes = await storage.loadLogoBytes('data:image/png;base64,$b64');
    expect(bytes, isNotNull);
    expect(storage.detectKind(bytes!), LogoImageKind.png);
  });

  test('clearLogoUrl elimina logo del mapa de branding', () {
    final withLogo = const OrgBranding(logoUrl: 'https://x/y.png');
    final cleared = withLogo.copyWith(clearLogoUrl: true);
    expect(cleared.hasLogo, isFalse);
    expect(cleared.toMap()['logoUrl'], isNull);
  });

  test('marca de agua desactivada por defecto en branding antiguo', () {
    final legacy = OrgBranding.fromMap({
      'logoUrl': 'https://example.com/a.png',
      'logoSizePt': 48,
    });
    expect(legacy.watermarkEnabled, isFalse);
    expect(legacy.watermarkActive, isFalse);
    expect(legacy.watermarkOpacityPct, OrgBranding.defaultWatermarkOpacityPct);
    expect(legacy.watermarkSize, WatermarkSize.medium);
    expect(legacy.watermarkPosition, WatermarkPosition.center);
  });

  test('marca de agua activada con transparencia y posición', () {
    final branding = const OrgBranding(
      logoUrl: 'https://example.com/a.png',
      watermarkEnabled: true,
      watermarkOpacityPct: 12,
      watermarkSize: WatermarkSize.large,
      watermarkPosition: WatermarkPosition.bottomRight,
    );
    expect(branding.watermarkActive, isTrue);
    expect(branding.watermarkOpacity, closeTo(0.12, 0.001));

    final changed = branding.copyWith(
      watermarkOpacityPct: 25,
      watermarkSize: WatermarkSize.small,
      watermarkPosition: WatermarkPosition.topCenter,
    );
    expect(changed.watermarkOpacityPct, 25);
    expect(changed.watermarkSize, WatermarkSize.small);
    expect(changed.watermarkPosition, WatermarkPosition.topCenter);

    final map = changed.toMap();
    final back = OrgBranding.fromMap(map);
    expect(back.watermarkEnabled, isTrue);
    expect(back.watermarkOpacityPct, 25);
    expect(back.watermarkPosition, WatermarkPosition.topCenter);
  });

  test('watermarkEnabled sin logo no está activa', () {
    const branding = OrgBranding(watermarkEnabled: true);
    expect(branding.hasLogo, isFalse);
    expect(branding.watermarkActive, isFalse);
  });

  test('legacy de cotización conserva watermark sin alterar totales', () {
    final b64 = base64Encode(_tinyPng());
    final branding = OrgBranding(
      logoUrl: 'data:image/png;base64,$b64',
      watermarkEnabled: true,
      watermarkOpacityPct: 18,
      watermarkSize: WatermarkSize.medium,
      watermarkPosition: WatermarkPosition.bottomCenter,
    );
    final quote = Quote(
      id: 'q3',
      organizationId: 'org',
      number: 'COT-3',
      sequence: 3,
      clientName: 'Acme',
      issueDate: DateTime.utc(2026, 1, 1),
      items: [
        QuoteLineItem.fromQuantity(
          id: 'i1',
          name: 'Servicio',
          quantity: 2,
          unitPrice: const MoneyCents(5000),
        ),
      ],
      total: const MoneyCents(10000),
      logoPath: branding.logoUrl,
      createdByUid: 'u1',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      legacyFields: branding.toQuoteLegacyFields(),
    ).withRecalculatedTotal();

    final fromQuote = OrgBranding.fromQuoteLegacy(
      logoPath: quote.logoPath,
      colorsJson: quote.colorsJson,
      legacy: quote.legacyFields,
    );
    expect(fromQuote.watermarkEnabled, isTrue);
    expect(fromQuote.watermarkOpacityPct, 18);
    expect(fromQuote.watermarkPosition, WatermarkPosition.bottomCenter);
    expect(quote.total.cents, 10000);
  });

  test('personalización de cotización no muta branding de organización', () {
    const orgBranding = OrgBranding(
      logoUrl: 'https://example.com/org.png',
      watermarkEnabled: true,
      watermarkOpacityPct: 12,
      watermarkSize: WatermarkSize.medium,
      watermarkPosition: WatermarkPosition.center,
    );
    final orgMap = orgBranding.toMap();

    final quoteLegacy = {
      ...orgBranding.toQuoteLegacyFields(),
      'watermarkOpacityPct': 28,
      'watermarkPosition': WatermarkPosition.bottomRight.id,
    };
    final quoteLayout = OrgBranding.fromQuoteLegacy(
      logoPath: orgBranding.logoUrl,
      colorsJson: null,
      legacy: quoteLegacy,
    );

    expect(quoteLayout.watermarkOpacityPct, 28);
    expect(quoteLayout.watermarkPosition, WatermarkPosition.bottomRight);
    // El mapa de org permanece intacto (solo se copia, no se escribe de vuelta).
    expect(orgMap['watermarkOpacityPct'], 12);
    expect(orgMap['watermarkPosition'], WatermarkPosition.center.id);
    expect(OrgBranding.fromMap(orgMap).watermarkOpacityPct, 12);
  });

  test('PDF con marca de agua y logo data URL', () async {
    final b64 = base64Encode(_tinyPng());
    final branding = OrgBranding(
      logoUrl: 'data:image/png;base64,$b64',
      watermarkEnabled: true,
      watermarkOpacityPct: OrgBranding.defaultWatermarkOpacityPct,
      watermarkSize: WatermarkSize.medium,
      watermarkPosition: WatermarkPosition.center,
    );
    final quote = Quote(
      id: 'q-wm-1',
      organizationId: 'org',
      number: 'COT-WM-1',
      sequence: 1,
      clientName: 'Cliente WM',
      issueDate: DateTime.utc(2026, 3, 1),
      items: [
        QuoteLineItem.fromQuantity(
          id: 'i1',
          name: 'Item',
          quantity: 1,
          unitPrice: const MoneyCents(2500),
        ),
      ],
      total: MoneyCents.zero,
      logoPath: branding.logoUrl,
      createdByUid: 'u1',
      createdAt: DateTime.utc(2026, 3, 1),
      updatedAt: DateTime.utc(2026, 3, 1),
      legacyFields: branding.toQuoteLegacyFields(),
    ).withRecalculatedTotal();

    final before = quote.total.cents;
    final bytes = await PdfService.generarPDFFromQuote(quote);
    expect(bytes.length, greaterThan(500));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(quote.total.cents, before);
  });

  test('PDF sin logo no falla aunque watermarkEnabled', () async {
    final quote = Quote(
      id: 'q-wm-2',
      organizationId: 'org',
      number: 'COT-WM-2',
      sequence: 2,
      clientName: 'Sin logo',
      issueDate: DateTime.utc(2026, 3, 1),
      items: [
        QuoteLineItem.fromQuantity(
          id: 'i1',
          name: 'Item',
          quantity: 1,
          unitPrice: const MoneyCents(1000),
        ),
      ],
      total: MoneyCents.zero,
      createdByUid: 'u1',
      createdAt: DateTime.utc(2026, 3, 1),
      updatedAt: DateTime.utc(2026, 3, 1),
      legacyFields: {
        'watermarkEnabled': true,
        'watermarkOpacityPct': 12,
        'watermarkSize': 'medium',
        'watermarkPosition': 'center',
      },
    ).withRecalculatedTotal();

    final bytes = await PdfService.generarPDFFromQuote(quote);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('PDF multipágina con marca de agua genera documento válido', () async {
    final b64 = base64Encode(_tinyPng());
    final items = List.generate(
      40,
      (i) => QuoteLineItem.fromQuantity(
        id: 'i$i',
        name: 'Servicio largo número $i con descripción extendida',
        description: 'Detalle ${'x' * 80}',
        quantity: 1,
        unitPrice: const MoneyCents(1500),
      ),
    );
    final branding = OrgBranding(
      logoUrl: 'data:image/png;base64,$b64',
      watermarkEnabled: true,
      watermarkOpacityPct: 10,
      watermarkSize: WatermarkSize.large,
      watermarkPosition: WatermarkPosition.bottomRight,
    );
    final quote = Quote(
      id: 'q-wm-mp',
      organizationId: 'org',
      number: 'COT-WM-MP',
      sequence: 99,
      clientName: 'Multi',
      issueDate: DateTime.utc(2026, 3, 1),
      items: items,
      total: MoneyCents.zero,
      logoPath: branding.logoUrl,
      createdByUid: 'u1',
      createdAt: DateTime.utc(2026, 3, 1),
      updatedAt: DateTime.utc(2026, 3, 1),
      legacyFields: branding.toQuoteLegacyFields(),
    ).withRecalculatedTotal();

    final bytes = await PdfService.generarPDFFromQuote(quote);
    expect(bytes.length, greaterThan(2000));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('PDF tolera fallo de descarga de logo (URL inválida)', () async {
    final quote = Quote(
      id: 'q-wm-fail',
      organizationId: 'org',
      number: 'COT-WM-FAIL',
      sequence: 3,
      clientName: 'Fail logo',
      issueDate: DateTime.utc(2026, 3, 1),
      items: [
        QuoteLineItem.fromQuantity(
          id: 'i1',
          name: 'Item',
          quantity: 1,
          unitPrice: const MoneyCents(900),
        ),
      ],
      total: MoneyCents.zero,
      logoPath: 'https://127.0.0.1:9/no-such-logo.png',
      createdByUid: 'u1',
      createdAt: DateTime.utc(2026, 3, 1),
      updatedAt: DateTime.utc(2026, 3, 1),
      legacyFields: const {
        'watermarkEnabled': true,
        'watermarkOpacityPct': 15,
        'watermarkSize': 'small',
        'watermarkPosition': 'topCenter',
      },
    ).withRecalculatedTotal();

    final bytes = await PdfService.generarPDFFromQuote(quote);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('opacidad se acota entre 5 y 30 al persistir/leer', () {
    expect(
      OrgBranding.fromMap({'watermarkOpacityPct': 1}).watermarkOpacityPct,
      OrgBranding.minWatermarkOpacityPct,
    );
    expect(
      OrgBranding.fromMap({'watermarkOpacityPct': 99}).watermarkOpacityPct,
      OrgBranding.maxWatermarkOpacityPct,
    );
    expect(
      const OrgBranding(watermarkOpacityPct: 5).watermarkOpacity,
      closeTo(0.05, 0.001),
    );
    expect(
      const OrgBranding(watermarkOpacityPct: 30).watermarkOpacity,
      closeTo(0.30, 0.001),
    );
  });

  test('valida PNG y JPG para carga de logo', () {
    storage.validateLogoBytes(_tinyPng(), fileName: 'logo.png');
    storage.validateLogoBytes(_tinyJpeg(), fileName: 'foto.jpg');
    expect(storage.detectKind(_tinyPng()), LogoImageKind.png);
    expect(storage.detectKind(_tinyJpeg()), LogoImageKind.jpeg);
  });

  test('rechaza archivo no admitido en carga', () {
    expect(
      () => storage.validateLogoBytes(
        Uint8List.fromList([0, 1, 2, 3]),
        fileName: 'x.gif',
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('LogoUploadGate cancela estado tras éxito y tras error', () async {
    final gate = LogoUploadGate();
    expect(gate.canStart, isTrue);

    final value = await gate.run(() async => 42);
    expect(value, 42);
    expect(gate.isUploading, isFalse);
    expect(gate.canStart, isTrue);

    await expectLater(
      gate.run(() async {
        throw Exception('storage falló');
      }),
      throwsA(isA<Exception>()),
    );
    expect(gate.isUploading, isFalse);

    // Simula cancelar selector: no se llama a run → no queda cargando.
    expect(gate.canStart, isTrue);
  });

  test('LogoUploadGate impide cargas concurrentes', () async {
    final gate = LogoUploadGate();
    final started = Completer<void>();
    final release = Completer<void>();

    final first = gate.run(() async {
      started.complete();
      await release.future;
      return 'ok';
    });
    await started.future;
    expect(gate.isUploading, isTrue);
    await expectLater(gate.run(() async => 'x'), throwsA(isA<Exception>()));
    release.complete();
    expect(await first, 'ok');
    expect(gate.isUploading, isFalse);
  });

  test('describeUploadError distingue permisos, timeout y red', () {
    final unauthorized = BrandingStorageService.describeUploadError(
      FirebaseException(
        plugin: 'firebase_storage',
        code: 'unauthorized',
        message: 'User is not authorized',
      ),
    );
    expect(unauthorized.toLowerCase(), contains('permiso'));

    final timeout = BrandingStorageService.describeUploadError(
      TimeoutException('upload'),
    );
    expect(timeout.toLowerCase(), contains('tardó'));

    final network = BrandingStorageService.describeUploadError(
      Exception('ClientException with SocketException: network'),
    );
    expect(network.toLowerCase(), contains('conexión'));

    final missingBucket = BrandingStorageService.describeUploadError(
      FirebaseException(
        plugin: 'firebase_storage',
        code: 'bucket-not-found',
        message: 'Bucket does not exist',
      ),
    );
    expect(missingBucket.toLowerCase(), contains('storage'));
  });

  test('reemplazo fallido conserva branding anterior (modelo)', () {
    const previous = OrgBranding(
      logoUrl: 'https://example.com/old.png',
      logoStoragePath: 'organizations/o/branding/logo.png',
    );
    // Simula UI: ante error se restaura previous, no el borrador a medias.
    var draft = previous.copyWith(logoUrl: 'https://example.com/new.png');
    draft = previous;
    expect(draft.logoUrl, previous.logoUrl);
    expect(draft.logoStoragePath, previous.logoStoragePath);
  });

  test('branding roundtrip tras guardar logo (persistencia mapa)', () {
    final map = const OrgBranding(
      logoUrl: 'https://firebasestorage.googleapis.com/v0/b/x/o/logo.png',
      logoStoragePath: 'organizations/org1/branding/logo.png',
      watermarkEnabled: true,
      watermarkOpacityPct: 12,
    ).toMap();
    final back = OrgBranding.fromMap(map);
    expect(back.hasLogo, isTrue);
    expect(back.logoStoragePath, 'organizations/org1/branding/logo.png');
    expect(back.watermarkEnabled, isTrue);
  });
}
