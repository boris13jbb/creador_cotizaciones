import 'package:creador_cotizaciones/core/utils/money_cents.dart';
import 'package:creador_cotizaciones/saas/domain/org_enums.dart';
import 'package:creador_cotizaciones/saas/models/quote.dart';
import 'package:creador_cotizaciones/saas/offline/offline_local_store.dart';
import 'package:creador_cotizaciones/saas/offline/offline_sync_service.dart';
import 'package:creador_cotizaciones/saas/offline/offline_sync_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    OfflineLocalStore.supportedOverrideForTests = null;
  });

  test('simulación Web: espejo SQLite no-op y sin abrir base', () async {
    OfflineLocalStore.supportedOverrideForTests = false;
    expect(OfflineLocalStore.isSupported, isFalse);

    final now = DateTime.now().toUtc();
    final quote = Quote(
      id: 'q-web-1',
      organizationId: 'org-web',
      number: 'LOCAL-WEBTEST1',
      sequence: 0,
      clientName: 'Web',
      issueDate: now,
      items: const [],
      charges: MoneyCents.zero,
      total: MoneyCents.zero,
      paymentMode: PaymentMode.single,
      payments: const [],
      createdByUid: 'u1',
      createdAt: now,
      updatedAt: now,
    );

    await OfflineLocalStore.instance.upsertQuote(
      uid: 'u1',
      quote: quote,
      status: OfflineSyncStatus.pending,
    );

    final listed = await OfflineLocalStore.instance.listQuotes(
      organizationId: 'org-web',
      uid: 'u1',
    );
    expect(listed, isEmpty);

    expect(
      await OfflineLocalStore.instance.countPending(
        organizationId: 'org-web',
        uid: 'u1',
      ),
      0,
    );
  });

  test('simulación Web: enqueue no finge cola local', () async {
    OfflineLocalStore.supportedOverrideForTests = false;

    await expectLater(
      OfflineLocalStore.instance.enqueue(
        organizationId: 'org-web',
        uid: 'u1',
        entityType: OfflineEntityType.quote,
        entityId: 'q1',
        operation: OfflineOperation.upsert,
        payload: const {'id': 'q1'},
        idempotencyKey: OfflineSyncService.idempotencyKey(
          type: OfflineEntityType.quote,
          entityId: 'q1',
          op: OfflineOperation.upsert,
          revision: '1',
        ),
      ),
      throwsA(isA<OfflineStoreUnsupportedException>()),
    );
  });

  test('simulación Web: syncPending no aborta como firebase_unreachable', () async {
    OfflineLocalStore.supportedOverrideForTests = false;
    final n = await OfflineSyncService.instance.syncPending(
      organizationId: 'org-web',
      uid: 'u1',
      forceRetry: true,
    );
    expect(n, 0);
    expect(OfflineSyncService.instance.lastItemError, isNull);
  });

  test('simulación nativa: isSupported permanece activo', () {
    OfflineLocalStore.supportedOverrideForTests = true;
    expect(OfflineLocalStore.isSupported, isTrue);
  });
}
