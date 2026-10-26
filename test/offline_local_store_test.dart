import 'package:creador_cotizaciones/core/utils/money_cents.dart';
import 'package:creador_cotizaciones/saas/domain/org_enums.dart';
import 'package:creador_cotizaciones/saas/domain/quote_totals.dart';
import 'package:creador_cotizaciones/saas/models/org_client.dart';
import 'package:creador_cotizaciones/saas/models/quote.dart';
import 'package:creador_cotizaciones/saas/offline/offline_database.dart';
import 'package:creador_cotizaciones/saas/offline/offline_local_store.dart';
import 'package:creador_cotizaciones/saas/offline/offline_sync_service.dart';
import 'package:creador_cotizaciones/saas/offline/offline_sync_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:universal_io/io.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await OfflineDatabase.instance.closeForTests();
    final path = p.join(await getDatabasesPath(), OfflineDatabase.dbName);
    await deleteDatabase(path);
  });

  tearDown(() async {
    await OfflineDatabase.instance.closeForTests();
  });

  test('guarda cotización offline con totales y modalidad de pago', () async {
    const calc = QuoteTotalsCalculator();
    final items = [
      QuoteLineItem.fromQuantity(
        id: 'i1',
        name: 'Servicio',
        description: 'Servicio',
        quantity: 2,
        unitPrice: const MoneyCents(5000),
      ),
    ];
    final totals = calc.calculate(
      items: items,
      globalDiscountBps: 0,
      globalDiscountFixed: MoneyCents.zero,
      charges: const MoneyCents(1000),
    );
    final now = DateTime.now().toUtc();
    final quote = Quote(
      id: 'q-offline-1',
      organizationId: 'org-a',
      number: 'LOCAL-ABCDEF12',
      sequence: 0,
      clientName: 'Cliente Offline',
      issueDate: now,
      items: items,
      charges: const MoneyCents(1000),
      total: totals.total,
      paymentMode: PaymentMode.single,
      payments: const [
        {'label': 'Pago único', 'amountCents': 11000},
      ],
      createdByUid: 'user-1',
      createdAt: now,
      updatedAt: now,
    );

    await OfflineLocalStore.instance.upsertQuote(
      uid: 'user-1',
      quote: quote,
      status: OfflineSyncStatus.pending,
    );

    final loaded = await OfflineLocalStore.instance.getQuote(
      organizationId: 'org-a',
      uid: 'user-1',
      quoteId: 'q-offline-1',
    );
    expect(loaded, isNotNull);
    expect(loaded!.syncStatus, OfflineSyncStatus.pending);
    expect(loaded.quote.total.cents, totals.total.cents);
    expect(loaded.quote.paymentMode, PaymentMode.single);
    expect(loaded.quote.charges.cents, 1000);
  });

  test('conserva anticipo y saldo (PaymentMode.split)', () async {
    final now = DateTime.now().toUtc();
    final quote = Quote(
      id: 'q-split-1',
      organizationId: 'org-a',
      number: 'LOCAL-SPLIT001',
      sequence: 0,
      clientName: 'Cliente Split',
      issueDate: now,
      items: [
        QuoteLineItem.fromQuantity(
          id: 'i1',
          name: 'Trabajo',
          description: 'Trabajo',
          quantity: 1,
          unitPrice: const MoneyCents(20000),
        ),
      ],
      total: const MoneyCents(20000),
      paymentMode: PaymentMode.split,
      payments: const [
        {'label': 'Anticipo', 'amountCents': 8000},
        {'label': 'Saldo', 'amountCents': 12000},
      ],
      createdByUid: 'user-1',
      createdAt: now,
      updatedAt: now,
    );

    await OfflineLocalStore.instance.upsertQuote(
      uid: 'user-1',
      quote: quote,
      status: OfflineSyncStatus.pending,
    );
    final loaded = await OfflineLocalStore.instance.getQuote(
      organizationId: 'org-a',
      uid: 'user-1',
      quoteId: 'q-split-1',
    );
    expect(loaded!.quote.paymentMode, PaymentMode.split);
    expect(loaded.quote.payments.length, 2);
    expect(loaded.quote.payments.first['amountCents'], 8000);
  });

  test('crea cliente offline y encola sin duplicar idempotency', () async {
    final now = DateTime.now().toUtc();
    final client = OrgClient(
      id: 'c-1',
      organizationId: 'org-a',
      name: 'Acme',
      createdAt: now,
      updatedAt: now,
    );
    await OfflineLocalStore.instance.upsertClient(
      uid: 'user-1',
      client: client,
      status: OfflineSyncStatus.pending,
    );
    final key = OfflineSyncService.idempotencyKey(
      type: OfflineEntityType.client,
      entityId: client.id,
      op: OfflineOperation.upsert,
      revision: now.toIso8601String(),
    );
    await OfflineLocalStore.instance.enqueue(
      organizationId: 'org-a',
      uid: 'user-1',
      entityType: OfflineEntityType.client,
      entityId: client.id,
      operation: OfflineOperation.upsert,
      payload: client.toMap(),
      idempotencyKey: key,
    );
    await OfflineLocalStore.instance.enqueue(
      organizationId: 'org-a',
      uid: 'user-1',
      entityType: OfflineEntityType.client,
      entityId: client.id,
      operation: OfflineOperation.upsert,
      payload: client.toMap(),
      idempotencyKey: key,
    );

    final pending = await OfflineLocalStore.instance.countPending(
      organizationId: 'org-a',
      uid: 'user-1',
    );
    expect(pending, 1);

    final clients = await OfflineLocalStore.instance.listClients(
      organizationId: 'org-a',
      uid: 'user-1',
    );
    expect(clients.single.name, 'Acme');
  });

  test('aísla datos entre organizaciones', () async {
    final now = DateTime.now().toUtc();
    await OfflineLocalStore.instance.upsertClient(
      uid: 'user-1',
      client: OrgClient(
        id: 'c-a',
        organizationId: 'org-a',
        name: 'Solo A',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await OfflineLocalStore.instance.upsertClient(
      uid: 'user-1',
      client: OrgClient(
        id: 'c-b',
        organizationId: 'org-b',
        name: 'Solo B',
        createdAt: now,
        updatedAt: now,
      ),
    );

    final a = await OfflineLocalStore.instance.listClients(
      organizationId: 'org-a',
      uid: 'user-1',
    );
    final b = await OfflineLocalStore.instance.listClients(
      organizationId: 'org-b',
      uid: 'user-1',
    );
    expect(a.map((e) => e.name), ['Solo A']);
    expect(b.map((e) => e.name), ['Solo B']);
  });

  test('registra varias operaciones pendientes sin duplicar claves', () async {
    final now = DateTime.now().toUtc();
    for (var i = 0; i < 3; i++) {
      final id = 'q-multi-$i';
      await OfflineLocalStore.instance.upsertQuote(
        uid: 'user-1',
        quote: Quote(
          id: id,
          organizationId: 'org-a',
          number: 'LOCAL-M$i',
          sequence: 0,
          clientName: 'C$i',
          issueDate: now,
          total: MoneyCents.zero,
          createdByUid: 'user-1',
          createdAt: now,
          updatedAt: now,
        ),
        status: OfflineSyncStatus.pending,
      );
      await OfflineLocalStore.instance.enqueue(
        organizationId: 'org-a',
        uid: 'user-1',
        entityType: OfflineEntityType.quote,
        entityId: id,
        operation: OfflineOperation.upsert,
        payload: {'id': id},
        idempotencyKey: OfflineSyncService.idempotencyKey(
          type: OfflineEntityType.quote,
          entityId: id,
          op: OfflineOperation.upsert,
          revision: 'v1',
        ),
      );
    }
    final pending = await OfflineLocalStore.instance.countPending(
      organizationId: 'org-a',
      uid: 'user-1',
    );
    final quotes = await OfflineLocalStore.instance.countPendingQuotes(
      organizationId: 'org-a',
      uid: 'user-1',
    );
    expect(pending, 3);
    expect(quotes, greaterThanOrEqualTo(3));
  });

  test('reintento actualiza next_attempt_at y conserva la fila', () async {
    await OfflineLocalStore.instance.enqueue(
      organizationId: 'org-a',
      uid: 'user-1',
      entityType: OfflineEntityType.client,
      entityId: 'c-retry',
      operation: OfflineOperation.upsert,
      payload: {'id': 'c-retry'},
      idempotencyKey: 'client:upsert:c-retry:v1',
    );
    final queue = await OfflineLocalStore.instance.pendingQueue(
      organizationId: 'org-a',
      uid: 'user-1',
    );
    expect(queue, isNotEmpty);
    final id = queue.first.id;
    await OfflineLocalStore.instance.markQueueFailed(
      id,
      'network',
      backoff: const Duration(milliseconds: 1),
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final again = await OfflineLocalStore.instance.pendingQueue(
      organizationId: 'org-a',
      uid: 'user-1',
    );
    expect(again.any((e) => e.id == id), isTrue);
    expect(again.firstWhere((e) => e.id == id).attempts, 1);
  });

  test('marca conflicto sin borrar la cotización local', () async {
    final now = DateTime.now().toUtc();
    final quote = Quote(
      id: 'q-conflict',
      organizationId: 'org-a',
      number: 'LOCAL-CONF',
      sequence: 0,
      clientName: 'X',
      issueDate: now,
      total: MoneyCents.zero,
      createdByUid: 'user-1',
      createdAt: now,
      updatedAt: now,
    );
    await OfflineLocalStore.instance.upsertQuote(
      uid: 'user-1',
      quote: quote,
      status: OfflineSyncStatus.pending,
    );
    await OfflineLocalStore.instance.markQuoteStatus(
      organizationId: 'org-a',
      uid: 'user-1',
      quoteId: 'q-conflict',
      status: OfflineSyncStatus.conflict,
      conflictPayloadJson: '{"remoteVersion":2}',
    );
    final loaded = await OfflineLocalStore.instance.getQuote(
      organizationId: 'org-a',
      uid: 'user-1',
      quoteId: 'q-conflict',
    );
    expect(loaded!.syncStatus, OfflineSyncStatus.conflict);
    expect(loaded.conflictPayloadJson, contains('remoteVersion'));
    expect(loaded.quote.clientName, 'X');
  });

  test('encola logo de cotización offline con quoteId y ruta local', () async {
    final tmp = Directory.systemTemp.createTempSync('coti_quote_logo_');
    addTearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });
    final file = File(p.join(tmp.path, 'quote_logos', 'q-logo-1.bin'));
    file.parent.createSync(recursive: true);
    await file.writeAsBytes(const [1, 2, 3, 4]);
    final localPath = file.path;

    expect(localPath.contains('quote_logos'), isTrue);
    expect(localPath.startsWith('http'), isFalse);

    await OfflineLocalStore.instance.enqueue(
      organizationId: 'org-a',
      uid: 'user-1',
      entityType: OfflineEntityType.brandingLogo,
      entityId: 'quote:q-logo-1',
      operation: OfflineOperation.uploadFile,
      payload: {'logoLocalPath': localPath, 'quoteId': 'q-logo-1'},
      idempotencyKey: OfflineSyncService.idempotencyKey(
        type: OfflineEntityType.brandingLogo,
        entityId: 'quote:q-logo-1',
        op: OfflineOperation.uploadFile,
        revision: 'v1',
      ),
    );

    final queue = await OfflineLocalStore.instance.pendingQueue(
      organizationId: 'org-a',
      uid: 'user-1',
    );
    final logoOps = queue
        .where((e) => e.entityType == OfflineEntityType.brandingLogo)
        .toList();
    expect(logoOps.length, 1);
    expect(logoOps.first.payload['quoteId'], 'q-logo-1');
    expect(logoOps.first.payload['logoLocalPath'], localPath);
    // La cola guarda ruta de archivo, no URL remota permanente.
    expect(
      '${logoOps.first.payload['logoLocalPath']}'.startsWith('https://'),
      isFalse,
    );
  });

  test(
    'UI pendingQuotes vs worker: backoff deja cola vacía hasta forzar',
    () async {
      final now = DateTime.now().toUtc();
      for (var i = 0; i < 5; i++) {
        final quote = Quote(
          id: 'q-back-$i',
          organizationId: 'org-a',
          number: 'LOCAL-B$i',
          sequence: 0,
          clientName: 'C$i',
          issueDate: now,
          total: MoneyCents.zero,
          createdByUid: 'user-1',
          createdAt: now,
          updatedAt: now,
        );
        await OfflineLocalStore.instance.upsertQuote(
          uid: 'user-1',
          quote: quote,
          status: OfflineSyncStatus.error,
        );
        await OfflineLocalStore.instance.enqueue(
          organizationId: 'org-a',
          uid: 'user-1',
          entityType: OfflineEntityType.quote,
          entityId: quote.id,
          operation: OfflineOperation.upsert,
          payload: quote.toMap()..['__isNew'] = true,
          idempotencyKey: 'quote:upsert:${quote.id}:v1',
        );
      }

      final queueBefore = await OfflineLocalStore.instance.pendingQueue(
        organizationId: 'org-a',
        uid: 'user-1',
      );
      expect(queueBefore.length, 5);

      // Simula fallos previos: backoff en el futuro.
      for (final item in queueBefore) {
        await OfflineLocalStore.instance.markQueueFailed(
          item.id,
          'simulated',
          backoff: const Duration(hours: 1),
        );
      }

      final uiCount = await OfflineLocalStore.instance.countPendingQuotes(
        organizationId: 'org-a',
        uid: 'user-1',
      );
      expect(uiCount, 5);

      final eligible = await OfflineLocalStore.instance.pendingQueue(
        organizationId: 'org-a',
        uid: 'user-1',
      );
      expect(eligible, isEmpty, reason: 'backoff debe excluir del worker');

      final forced = await OfflineLocalStore.instance.pendingQueue(
        organizationId: 'org-a',
        uid: 'user-1',
        forceIgnoreBackoff: true,
      );
      expect(forced.length, 5);

      final diag = await OfflineLocalStore.instance.queueDiagnostics(
        organizationId: 'org-a',
        uid: 'user-1',
      );
      expect(diag.pendingLocalQuotes, 5);
      expect(diag.incompleteQueue, 5);
      expect(diag.eligibleNow, 0);
      expect(diag.blockedByBackoff, 5);
    },
  );

  test('repara cotizaciones locales sin fila de cola (huérfanas)', () async {
    final now = DateTime.now().toUtc();
    final quote = Quote(
      id: 'q-orphan-1',
      organizationId: 'org-a',
      number: 'LOCAL-ORPHAN1',
      sequence: 0,
      clientName: 'Huérfana',
      issueDate: now,
      total: MoneyCents.zero,
      createdByUid: 'user-1',
      createdAt: now,
      updatedAt: now,
    );
    await OfflineLocalStore.instance.upsertQuote(
      uid: 'user-1',
      quote: quote,
      status: OfflineSyncStatus.pending,
    );

    expect(
      await OfflineLocalStore.instance.countPendingQuotes(
        organizationId: 'org-a',
        uid: 'user-1',
      ),
      1,
    );
    expect(
      await OfflineLocalStore.instance.pendingQueue(
        organizationId: 'org-a',
        uid: 'user-1',
        forceIgnoreBackoff: true,
      ),
      isEmpty,
    );

    final n = await OfflineLocalStore.instance.ensureQueueForUnsyncedQuotes(
      organizationId: 'org-a',
      uid: 'user-1',
    );
    expect(n, 1);

    final queue = await OfflineLocalStore.instance.pendingQueue(
      organizationId: 'org-a',
      uid: 'user-1',
      forceIgnoreBackoff: true,
    );
    expect(queue.length, 1);
    expect(queue.first.entityId, 'q-orphan-1');
    expect(queue.first.payload['__isNew'], isTrue);
    // Segunda reparación no duplica fila activa.
    expect(
      await OfflineLocalStore.instance.ensureQueueForUnsyncedQuotes(
        organizationId: 'org-a',
        uid: 'user-1',
      ),
      0,
    );
  });

  test(
    'archivar actualiza payload local a archived (no retiene draft)',
    () async {
      final now = DateTime.now().toUtc();
      final draft = Quote(
        id: 'q-arch-1',
        organizationId: 'org-a',
        number: 'COT-009',
        sequence: 9,
        status: QuoteStatus.draft,
        clientName: 'Cliente',
        issueDate: now,
        total: const MoneyCents(1000),
        createdByUid: 'user-1',
        createdAt: now,
        updatedAt: now,
      );
      await OfflineLocalStore.instance.upsertQuote(
        uid: 'user-1',
        quote: draft,
        status: OfflineSyncStatus.synced,
      );

      final archived = draft.copyWith(
        status: QuoteStatus.archived,
        updatedAt: now.add(const Duration(seconds: 1)),
      );
      await OfflineLocalStore.instance.upsertQuote(
        uid: 'user-1',
        quote: archived,
        status: OfflineSyncStatus.synced,
      );

      final loaded = await OfflineLocalStore.instance.getQuote(
        organizationId: 'org-a',
        uid: 'user-1',
        quoteId: 'q-arch-1',
      );
      expect(loaded, isNotNull);
      expect(loaded!.quote.status, QuoteStatus.archived);
      expect(loaded.syncStatus, OfflineSyncStatus.synced);
    },
  );
}
