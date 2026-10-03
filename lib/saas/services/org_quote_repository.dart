import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../config/saas_platform.dart';
import '../domain/org_enums.dart';
import '../models/organization.dart';
import '../models/quote.dart';
import 'auth_service.dart';
import 'firestore_rest_client.dart';
import 'identity_toolkit_client.dart';
import 'organization_service.dart';

/// Repositorio de cotizaciones por organización con numeración atómica.
class OrgQuoteRepository {
  OrgQuoteRepository._();
  static final OrgQuoteRepository instance = OrgQuoteRepository._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  bool get _useRest => saasUseRestBackend;

  CollectionReference<Map<String, dynamic>> _quotes(String orgId) =>
      _db.collection('organizations').doc(orgId).collection('quotes');

  DocumentReference<Map<String, dynamic>> _counter(String orgId) => _db
      .collection('organizations')
      .doc(orgId)
      .collection('counters')
      .doc('quotes');

  /// Reserva el siguiente número de forma atómica (transacción Firestore).
  Future<({int sequence, String number})> allocateNumber({
    required String orgId,
    required String prefix,
    AuthSession? session,
  }) async {
    if (_useRest) {
      // En REST usamos compare-and-swap simple sobre el contador.
      return _allocateNumberRest(
        orgId: orgId,
        prefix: prefix,
        session: session,
      );
    }

    return _db.runTransaction((tx) async {
      final ref = _counter(orgId);
      final snap = await tx.get(ref);
      final current = (snap.data()?['seq'] as num?)?.toInt() ?? 0;
      final next = current + 1;
      tx.set(ref, {
        'seq': next,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      }, SetOptions(merge: true));
      final number = '$prefix-${next.toString().padLeft(3, '0')}';
      return (sequence: next, number: number);
    });
  }

  Future<({int sequence, String number})> _allocateNumberRest({
    required String orgId,
    required String prefix,
    AuthSession? session,
  }) async {
    final s = session ?? AuthService.instance.restSession;
    if (s == null) throw Exception('Sesión no disponible');

    // Reintento acotado para reducir colisiones entre dispositivos.
    for (var attempt = 0; attempt < 5; attempt++) {
      final path = 'organizations/$orgId/counters/quotes';
      final current = await FirestoreRestClient.instance.getDocument(
        session: s,
        path: path,
      );
      final seq = (current?['seq'] as num?)?.toInt() ?? 0;
      final next = seq + 1;
      await FirestoreRestClient.instance.upsertDocument(
        session: s,
        path: path,
        data: {
          'seq': next,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
          'prevSeq': seq,
        },
      );
      // Verificación optimista: releer
      final verify = await FirestoreRestClient.instance.getDocument(
        session: s,
        path: path,
      );
      final verified = (verify?['seq'] as num?)?.toInt() ?? 0;
      if (verified == next) {
        return (
          sequence: next,
          number: '$prefix-${next.toString().padLeft(3, '0')}',
        );
      }
      await Future<void>.delayed(Duration(milliseconds: 50 * (attempt + 1)));
    }
    throw Exception(
      'No se pudo asignar número atómico. Reintenta o usa Cloud Function allocateQuoteNumber.',
    );
  }

  Future<void> upsertQuote(Quote quote, {AuthSession? session}) async {
    final data = quote.toMap();
    if (_useRest) {
      final s = session ?? AuthService.instance.restSession;
      if (s == null) throw Exception('Sesión no disponible');
      await FirestoreRestClient.instance.upsertDocument(
        session: s,
        path: 'organizations/${quote.organizationId}/quotes/${quote.id}',
        data: data,
      );
      return;
    }
    await _quotes(
      quote.organizationId,
    ).doc(quote.id).set(data, SetOptions(merge: true));
  }

  Future<void> deleteQuote({
    required String orgId,
    required String quoteId,
    AuthSession? session,
  }) async {
    if (_useRest) {
      final s = session ?? AuthService.instance.restSession;
      if (s == null) throw Exception('Sesión no disponible');
      await FirestoreRestClient.instance.deleteDocument(
        session: s,
        path: 'organizations/$orgId/quotes/$quoteId',
      );
      return;
    }
    await _quotes(orgId).doc(quoteId).delete();
  }

  Future<Quote?> getQuote({
    required String orgId,
    required String quoteId,
    AuthSession? session,
  }) async {
    if (_useRest) {
      final s = session ?? AuthService.instance.restSession;
      if (s == null) return null;
      final map = await FirestoreRestClient.instance.getDocument(
        session: s,
        path: 'organizations/$orgId/quotes/$quoteId',
      );
      if (map == null) return null;
      return Quote.fromMap(map);
    }
    final snap = await _quotes(orgId).doc(quoteId).get();
    if (!snap.exists || snap.data() == null) return null;
    return Quote.fromMap(snap.data()!);
  }

  /// Lista paginada por `updatedAt` descendente.
  Future<QuotePage> listQuotes({
    required String orgId,
    int limit = 20,
    String? status,
    String? startAfterUpdatedAt,
    AuthSession? session,
  }) async {
    if (_useRest) {
      final s = session ?? AuthService.instance.restSession;
      if (s == null) {
        return const QuotePage(items: [], hasMore: false);
      }
      final all = await FirestoreRestClient.instance.listCollection(
        session: s,
        path: 'organizations/$orgId/quotes',
        pageSize: 100,
      );
      var quotes = all.map(Quote.fromMap).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      if (status != null && status.isNotEmpty) {
        quotes = quotes.where((q) => q.status.id == status).toList();
      }
      if (startAfterUpdatedAt != null) {
        final cursor = DateTime.tryParse(startAfterUpdatedAt);
        if (cursor != null) {
          quotes = quotes.where((q) => q.updatedAt.isBefore(cursor)).toList();
        }
      }
      final page = quotes.take(limit).toList();
      final hasMore = quotes.length > limit;
      return QuotePage(
        items: page,
        nextCursor: hasMore && page.isNotEmpty
            ? page.last.updatedAt.toIso8601String()
            : null,
        hasMore: hasMore,
      );
    }

    Query<Map<String, dynamic>> q = _quotes(
      orgId,
    ).orderBy('updatedAt', descending: true);
    if (status != null && status.isNotEmpty) {
      q = _quotes(orgId)
          .where('status', isEqualTo: status)
          .orderBy('updatedAt', descending: true);
    }
    if (startAfterUpdatedAt != null) {
      q = q.startAfter([startAfterUpdatedAt]);
    }
    final snap = await q.limit(limit + 1).get();
    final docs = snap.docs;
    final hasMore = docs.length > limit;
    final pageDocs = hasMore ? docs.sublist(0, limit) : docs;
    final items = pageDocs.map((d) => Quote.fromMap(d.data())).toList();
    return QuotePage(
      items: items,
      nextCursor: hasMore && items.isNotEmpty
          ? items.last.updatedAt.toIso8601String()
          : null,
      hasMore: hasMore,
    );
  }

  Future<int> countQuotes(String orgId, {AuthSession? session}) async {
    if (_useRest) {
      final page = await listQuotes(orgId: orgId, limit: 500, session: session);
      return page.items.length;
    }
    try {
      final agg = await _quotes(orgId).count().get();
      return agg.count ?? 0;
    } catch (e) {
      debugPrint('countQuotes: $e');
      final snap = await _quotes(orgId).limit(500).get();
      return snap.docs.length;
    }
  }

  Future<Organization?> requireWritableOrg({
    required String orgId,
    required String uid,
    AuthSession? session,
  }) async {
    final membership = await OrganizationService.instance.getMembership(
      orgId: orgId,
      uid: uid,
      session: session,
    );
    if (membership == null ||
        membership.status != MembershipStatus.active ||
        !membership.role.canWriteQuotes) {
      throw Exception('No tienes permiso para modificar cotizaciones.');
    }
    return OrganizationService.instance.getOrganization(
      orgId,
      session: session,
    );
  }

  Future<Quote> updateStatus({
    required Quote quote,
    required QuoteStatus status,
    AuthSession? session,
  }) async {
    final updated = quote.copyWith(
      status: status,
      updatedAt: DateTime.now().toUtc(),
    );
    await upsertQuote(updated, session: session);
    return updated;
  }

  /// Duplica con nuevo id y número atómico; estado borrador.
  Future<Quote> duplicateQuote({
    required Quote source,
    required String prefix,
    required String createdByUid,
    AuthSession? session,
  }) async {
    final allocated = await allocateNumber(
      orgId: source.organizationId,
      prefix: prefix,
      session: session,
    );
    final now = DateTime.now().toUtc();
    final copy = source
        .copyWith(
          id: const Uuid().v4(),
          number: allocated.number,
          sequence: allocated.sequence,
          status: QuoteStatus.draft,
          version: 1,
          previousVersionId: null,
          createdByUid: createdByUid,
          updatedByUid: createdByUid,
          createdAt: now,
          updatedAt: now,
        )
        .withRecalculatedTotal();
    await upsertQuote(copy, session: session);
    return copy;
  }

  /// Nueva versión: archiva la anterior y crea borrador versionado.
  Future<Quote> createVersion({
    required Quote source,
    required String createdByUid,
    AuthSession? session,
  }) async {
    await updateStatus(
      quote: source,
      status: QuoteStatus.archived,
      session: session,
    );
    final now = DateTime.now().toUtc();
    final next = source
        .copyWith(
          id: const Uuid().v4(),
          status: QuoteStatus.draft,
          version: source.version + 1,
          previousVersionId: source.id,
          createdByUid: createdByUid,
          updatedByUid: createdByUid,
          createdAt: now,
          updatedAt: now,
        )
        .withRecalculatedTotal();
    await upsertQuote(next, session: session);
    return next;
  }
}
