import 'dart:convert';
import 'dart:typed_data';

import 'package:creador_cotizaciones/core/utils/money_cents.dart';
import 'package:creador_cotizaciones/saas/models/org_branding.dart';
import 'package:creador_cotizaciones/saas/models/organization.dart';
import 'package:creador_cotizaciones/saas/models/quote.dart';
import 'package:creador_cotizaciones/saas/offline/branding_local_cache.dart';
import 'package:creador_cotizaciones/saas/offline/offline_database.dart';
import 'package:creador_cotizaciones/saas/providers/quote_editor_controller.dart';
import 'package:creador_cotizaciones/saas/services/branding_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:universal_io/io.dart';

/// PNG 1×1 (logo de cotización).
Uint8List _quotePng() => Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  ),
);

/// JPEG mínimo distinto (logo de empresa en caché).
Uint8List _orgJpeg() => Uint8List.fromList([
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
  0x19,
  0x1A,
  0x1C,
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
  0x03,
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

Quote _blankQuote({required String logoPath}) {
  final now = DateTime.now().toUtc();
  return Quote(
    id: 'q-logo-priority',
    organizationId: 'org-logo',
    number: 'COT-007',
    sequence: 7,
    clientName: 'Cliente',
    issueDate: now,
    total: MoneyCents.zero,
    logoPath: logoPath,
    createdByUid: 'user-1',
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docsRoot;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    docsRoot = Directory.systemTemp.createTempSync('coti_docs_');
    BrandingLocalCache.documentsRootOverride = docsRoot.path;
    OfflineDatabase.databaseNameOverride = 'cotiapp_offline_logo_priority.db';

    await OfflineDatabase.instance.closeForTests();
    final path = p.join(
      await getDatabasesPath(),
      OfflineDatabase.databaseNameOverride!,
    );
    await deleteDatabase(path);
  });

  tearDown(() async {
    BrandingLocalCache.documentsRootOverride = null;
    await OfflineDatabase.instance.closeForTests();
    final name = OfflineDatabase.databaseNameOverride;
    OfflineDatabase.databaseNameOverride = null;
    if (name != null) {
      final path = p.join(await getDatabasesPath(), name);
      await deleteDatabase(path);
    }
    if (docsRoot.existsSync()) {
      docsRoot.deleteSync(recursive: true);
    }
  });

  test(
    'loadLogoBytes prioriza archivo de cotización sobre caché de empresa',
    () async {
      const orgId = 'org-logo';
      const uid = 'user-1';
      final quoteBytes = _quotePng();
      final orgBytes = _orgJpeg();

      await BrandingLocalCache.instance.saveLogoBytes(
        organizationId: orgId,
        uid: uid,
        bytes: orgBytes,
        branding: const OrgBranding(
          logoUrl: 'https://example.com/org-logo.png',
        ),
        pendingUpload: false,
      );

      final quotePath = await BrandingLocalCache.instance.saveQuoteLogoBytes(
        organizationId: orgId,
        quoteId: 'q-logo-priority',
        bytes: quoteBytes,
      );
      expect(quotePath, isNotNull);

      final loaded = await BrandingStorageService.instance.loadLogoBytes(
        quotePath,
        organizationId: orgId,
        uid: uid,
      );
      expect(loaded, isNotNull);
      expect(loaded!.length, quoteBytes.length);
      expect(loaded[0], 0x89);
      expect(loaded[1], 0x50);
    },
  );

  test(
    'sin logo propio, loadLogoBytes usa caché de empresa como respaldo',
    () async {
      const orgId = 'org-logo';
      const uid = 'user-1';
      final orgBytes = _orgJpeg();

      await BrandingLocalCache.instance.saveLogoBytes(
        organizationId: orgId,
        uid: uid,
        bytes: orgBytes,
        branding: const OrgBranding(
          logoUrl: 'https://example.com/org-logo.png',
        ),
        pendingUpload: false,
      );

      final loaded = await BrandingStorageService.instance.loadLogoBytes(
        null,
        organizationId: orgId,
        uid: uid,
      );
      expect(loaded, isNotNull);
      expect(loaded!.length, orgBytes.length);
      expect(loaded[0], 0xFF);
    },
  );

  test('saveQuoteLogoBytes no reemplaza logo.bin de la empresa', () async {
    const orgId = 'org-logo';
    const uid = 'user-1';
    final orgBytes = _orgJpeg();
    final quoteBytes = _quotePng();

    final orgPath = await BrandingLocalCache.instance.saveLogoBytes(
      organizationId: orgId,
      uid: uid,
      bytes: orgBytes,
      branding: const OrgBranding(logoUrl: 'https://example.com/org-logo.png'),
    );
    final quotePath = await BrandingLocalCache.instance.saveQuoteLogoBytes(
      organizationId: orgId,
      quoteId: 'q-separate',
      bytes: quoteBytes,
    );

    expect(orgPath, isNotNull);
    expect(quotePath, isNotNull);
    expect(quotePath!.contains('quote_logos'), isTrue);
    expect(orgPath!.endsWith('logo.bin'), isTrue);
    expect(quotePath, isNot(orgPath));

    final stillOrg = await BrandingLocalCache.instance.loadLogoBytes(
      organizationId: orgId,
      uid: uid,
    );
    expect(stillOrg, isNotNull);
    expect(stillOrg![0], 0xFF);
  });

  test(
    'setLogoPath conserva override; applyOrganizationBranding limpia a herencia',
    () async {
      final customPath = p.join(docsRoot.path, 'coti_custom_logo.bin');
      final ctrl = QuoteEditorController(
        uid: 'user-1',
        organizationId: 'org-logo',
        initialQuote: _blankQuote(logoPath: 'https://example.com/org-logo.png'),
        resumeDraft: false,
      );
      for (var i = 0; i < 20 && ctrl.initializing; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      ctrl.setLogoPath(customPath);
      expect(ctrl.quote.logoPath, customPath);

      final now = DateTime.now().toUtc();
      await ctrl.applyOrganizationBranding(
        organization: Organization(
          id: 'org-logo',
          name: 'Empresa',
          ownerUid: 'user-1',
          branding: const OrgBranding(
            logoUrl: 'https://example.com/org-logo.png',
          ).toMap(),
          createdAt: now,
          updatedAt: now,
        ),
      );
      // Hereda global: no stamp de URL (null → resolución usa OrgBranding).
      expect(ctrl.quote.logoPath, isNull);
      ctrl.dispose();
    },
  );

  test('quotePath Storage es distinto del logo.png de empresa', () {
    final svc = BrandingStorageService.instance;
    expect(svc.orgPath('org-a'), 'organizations/org-a/branding/logo.png');
    expect(
      svc.quotePath('org-a', 'q-1'),
      'organizations/org-a/branding/quote_q-1.png',
    );
    expect(svc.isQuoteLogoStoragePath(svc.quotePath('org-a', 'q-1')), isTrue);
    expect(svc.isOrgLogoStoragePath(svc.orgPath('org-a')), isTrue);
    expect(svc.isOrgLogoStoragePath(svc.quotePath('org-a', 'q-1')), isFalse);
  });

  test('nueva cotización no stamp del logo global en logoPath', () async {
    final now = DateTime.now().toUtc();
    final ctrl = QuoteEditorController(
      uid: 'user-1',
      organizationId: 'org-logo',
      initialQuote: Quote(
        id: 'q-new',
        organizationId: 'org-logo',
        number: 'LOCAL-1',
        sequence: 0,
        clientName: '',
        issueDate: now,
        total: MoneyCents.zero,
        createdByUid: 'user-1',
        createdAt: now,
        updatedAt: now,
      ),
      resumeDraft: false,
    );
    for (var i = 0; i < 40 && ctrl.initializing; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    await ctrl.applyOrganizationBranding(
      organization: Organization(
        id: 'org-logo',
        name: 'Empresa',
        ownerUid: 'user-1',
        branding: const OrgBranding(
          logoUrl: 'https://example.com/org-logo.png',
        ).toMap(),
        createdAt: now,
        updatedAt: now,
      ),
    );
    expect(ctrl.quote.logoPath, isNull);
    ctrl.dispose();
  });
}
