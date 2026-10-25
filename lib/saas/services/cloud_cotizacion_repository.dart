import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/cotizacion.dart';
import '../../models/servicio.dart';
import '../config/saas_platform.dart';
import '../domain/org_enums.dart';
import '../models/quote.dart';
import '../offline/connectivity_monitor.dart';
import '../offline/offline_controller.dart';
import '../offline/offline_local_store.dart';
import '../offline/offline_sync_service.dart';
import '../offline/offline_sync_status.dart';
import '../providers/auth_controller.dart';
import 'activity_repository.dart';
import 'app_logger.dart';
import 'firestore_rest_client.dart';
import 'org_quote_repository.dart';
import 'organization_service.dart';
import 'quote_mapper.dart';

/// Página de historial adaptada al modelo UI.
class CotizacionPage {
  final List<Cotizacion> items;
  final String? nextCursor;
  final bool hasMore;

  const CotizacionPage({
    required this.items,
    this.nextCursor,
    required this.hasMore,
  });
}

/// Repositorio cloud de cotizaciones.
/// Preferente: `organizations/{orgId}/quotes`. Fallback legacy: `users/{uid}/cotizaciones`.
class CloudCotizacionRepository {
  CloudCotizacionRepository._();
  static final CloudCotizacionRepository instance =
      CloudCotizacionRepository._();

  FirebaseFirestore? _db;
  AuthController? _auth;

  @visibleForTesting
  static bool useEmptyStoreForTests = false;

  void bindAuth(AuthController auth) => _auth = auth;

  FirebaseFirestore get _firestore {
    _db ??= FirebaseFirestore.instance;
    return _db!;
  }

  bool get _useRest {
    if (saasUseRestBackend) return true;
    if (_auth?.restSession == null) return false;
    try {
      return FirebaseAuth.instance.currentUser == null;
    } catch (_) {
      return true;
    }
  }

  String get _uid {
    if (_useRest) {
      final rest = _auth?.restSession?.uid;
      if (rest != null && rest.isNotEmpty) return rest;
      throw Exception('Debes iniciar sesión para continuar.');
    }
    final native = FirebaseAuth.instance.currentUser?.uid;
    if (native != null) return native;
    throw Exception('Debes iniciar sesión para continuar.');
  }

  String? get _orgId =>
      _auth?.organization?.id ?? _auth?.profile?.defaultOrganizationId;

  CollectionReference<Map<String, dynamic>> get _legacyCol =>
      _firestore.collection('users').doc(_uid).collection('cotizaciones');

  Future<void> insertarCotizacion(Cotizacion cot) async {
    final access = _auth?.access;
    final max = access?.maxCotizaciones ?? 5;
    final actuales = await obtenerTodas();
    final exists = actuales.any((c) => c.id == cot.id);
    if (!exists && actuales.length >= max) {
      throw Exception(
        'Límite del plan ${access?.effectivePlan.label ?? 'Free'}: máximo $max cotizaciones. '
        'Actualiza a Pro para continuar.',
      );
    }

    final orgId = _orgId;
    if (orgId != null && orgId.isNotEmpty) {
      await _upsertOrgQuote(cot, orgId: orgId, isNew: !exists);
      // Dual-write legacy durante transición (no pierde datos si falla org).
      try {
        await _upsertLegacy(cot);
      } catch (e, st) {
        debugPrint('dual-write legacy: $e\n$st');
      }
      return;
    }

    await _upsertLegacy(cot);
  }

  Future<void> _upsertOrgQuote(
    Cotizacion cot, {
    required String orgId,
    required bool isNew,
  }) async {
    final session = _auth?.restSession;
    final org = await OrganizationService.instance.getOrganization(
      orgId,
      session: session,
    );
    var sequence = 0;
    var number = cot.numero;
    if (isNew) {
      final allocated = await OrgQuoteRepository.instance.allocateNumber(
        orgId: orgId,
        prefix: org?.quotePrefix ?? 'COT',
        session: session,
      );
      sequence = allocated.sequence;
      number = allocated.number;
    }

    final quote = QuoteMapper.fromCotizacion(
      Cotizacion(
        id: cot.id,
        numero: number,
        fecha: cot.fecha,
        cliente: cot.cliente,
        ubicacion: cot.ubicacion,
        tipoServicio: cot.tipoServicio,
        cantidadEquipos: cot.cantidadEquipos,
        tiempoEstimado: cot.tiempoEstimado,
        descripcion: cot.descripcion,
        servicios: cot.servicios,
        total: cot.total,
        incluye: cot.incluye,
        noIncluye: cot.noIncluye,
        notas: cot.notas,
        logoPath: cot.logoPath,
        subtitulo: cot.subtitulo,
        validezDias: cot.validezDias,
        footerText: cot.footerText,
        firmaTecnicoLabel: cot.firmaTecnicoLabel,
        firmaClienteLabel: cot.firmaClienteLabel,
        formaPagoJson: cot.formaPagoJson,
        camposExtra: cot.camposExtra,
        coloresJson: cot.coloresJson,
      ),
      organizationId: orgId,
      createdByUid: _uid,
      sequence: sequence,
      currency: org?.currency ?? 'USD',
      legacyUserPath: 'users/$_uid/cotizaciones/${cot.id}',
      status: QuoteStatus.draft,
    );

    await OrgQuoteRepository.instance.upsertQuote(quote, session: session);
  }

  Future<void> _upsertLegacy(Cotizacion cot) async {
    if (_useRest) {
      final session = _auth!.restSession!;
      await FirestoreRestClient.instance.upsertCotizacion(
        session: session,
        cot: cot,
      );
      return;
    }
    final data = cot.toMap();
    data['userId'] = _uid;
    data['servicios'] = cot.servicios.map((s) => s.toMap()).toList();
    data['updatedAt'] = DateTime.now().toIso8601String();
    await _legacyCol.doc(cot.id).set(data, SetOptions(merge: true));
  }

  Future<List<Cotizacion>> obtenerTodas() async {
    if (useEmptyStoreForTests) return [];

    final orgId = _orgId;
    List<Cotizacion> remote = [];
    if (orgId != null && orgId.isNotEmpty) {
      try {
        final page = await OrgQuoteRepository.instance.listQuotes(
          orgId: orgId,
          limit: 200,
          session: _auth?.restSession,
        );
        remote = [for (final q in page.items) QuoteMapper.toCotizacion(q)];
        // Espejo local de lo remoto (disponible offline después).
        try {
          final uid = _uid;
          for (final q in page.items) {
            await OfflineLocalStore.instance.upsertQuote(
              uid: uid,
              quote: q,
              status: OfflineSyncStatus.synced,
            );
          }
        } catch (e) {
          debugPrint('obtenerTodas mirror: $e');
        }
      } catch (e, st) {
        debugPrint('obtenerTodas org: $e\n$st');
      }
    }

    if (orgId != null && orgId.isNotEmpty) {
      try {
        final local = await OfflineLocalStore.instance.listQuotes(
          organizationId: orgId,
          uid: _uid,
        );
        final byId = <String, Cotizacion>{
          for (final c in remote) c.id: c,
        };
        for (final rec in local) {
          final cot = QuoteMapper.toCotizacion(rec.quote)
              .withOfflineSyncStatus(rec.syncStatus.id);
          final preferLocal =
              rec.syncStatus == OfflineSyncStatus.pending ||
              rec.syncStatus == OfflineSyncStatus.conflict ||
              rec.syncStatus == OfflineSyncStatus.error ||
              !byId.containsKey(cot.id);
          if (preferLocal) {
            byId[cot.id] = cot;
          }
        }
        if (byId.isNotEmpty) {
          final merged = byId.values.toList()
            ..sort((a, b) => b.fecha.compareTo(a.fecha));
          return merged;
        }
      } catch (e) {
        debugPrint('obtenerTodas local: $e');
      }
    }

    if (remote.isNotEmpty) return remote;
    return _obtenerLegacy();
  }

  /// Historial paginado por cursor (`updatedAt`). Fusiona pendientes locales.
  Future<CotizacionPage> obtenerPagina({
    int limit = 20,
    String? startAfterUpdatedAt,
    String? status,
  }) async {
    if (useEmptyStoreForTests) {
      return const CotizacionPage(items: [], hasMore: false);
    }

    final orgId = _orgId;
    List<Cotizacion> remote = [];
    String? nextCursor;
    var hasMore = false;

    if (orgId != null && orgId.isNotEmpty) {
      try {
        final page = await OrgQuoteRepository.instance.listQuotes(
          orgId: orgId,
          limit: limit,
          status: status,
          startAfterUpdatedAt: startAfterUpdatedAt,
          session: _auth?.restSession,
        );
        remote = [for (final q in page.items) QuoteMapper.toCotizacion(q)];
        nextCursor = page.nextCursor;
        hasMore = page.hasMore;
        try {
          for (final q in page.items) {
            await OfflineLocalStore.instance.upsertQuote(
              uid: _uid,
              quote: q,
              status: OfflineSyncStatus.synced,
            );
          }
        } catch (e) {
          debugPrint('obtenerPagina mirror: $e');
        }
      } catch (e, st) {
        debugPrint('obtenerPagina org: $e\n$st');
      }
    }

    // Primera página (o fallo de red): incluir locales pendientes/solo-dispositivo.
    if (orgId != null &&
        orgId.isNotEmpty &&
        startAfterUpdatedAt == null) {
      try {
        final local = await OfflineLocalStore.instance.listQuotes(
          organizationId: orgId,
          uid: _uid,
        );
        final byId = <String, Cotizacion>{for (final c in remote) c.id: c};
        for (final rec in local) {
          if (status != null &&
              status.isNotEmpty &&
              rec.quote.status.id != status) {
            continue;
          }
          final cot = QuoteMapper.toCotizacion(rec.quote)
              .withOfflineSyncStatus(rec.syncStatus.id);
          final preferLocal =
              rec.syncStatus == OfflineSyncStatus.pending ||
              rec.syncStatus == OfflineSyncStatus.conflict ||
              rec.syncStatus == OfflineSyncStatus.error ||
              !byId.containsKey(cot.id);
          if (preferLocal) {
            byId[cot.id] = cot;
          } else {
            byId[cot.id] = byId[cot.id]!.withOfflineSyncStatus(
              OfflineSyncStatus.synced.id,
            );
          }
        }
        final merged = byId.values.toList()
          ..sort((a, b) => b.fecha.compareTo(a.fecha));
        if (merged.isNotEmpty || remote.isNotEmpty) {
          return CotizacionPage(
            items: merged.take(limit).toList(),
            nextCursor: nextCursor,
            hasMore: hasMore || merged.length > limit,
          );
        }
      } catch (e) {
        debugPrint('obtenerPagina local: $e');
      }
    } else if (remote.isNotEmpty) {
      return CotizacionPage(
        items: remote,
        nextCursor: nextCursor,
        hasMore: hasMore,
      );
    }

    if (startAfterUpdatedAt != null || (status != null && status.isNotEmpty)) {
      if (remote.isNotEmpty) {
        return CotizacionPage(
          items: remote,
          nextCursor: nextCursor,
          hasMore: hasMore,
        );
      }
      return const CotizacionPage(items: [], hasMore: false);
    }
    final legacy = await _obtenerLegacy();
    return CotizacionPage(items: legacy, nextCursor: null, hasMore: false);
  }

  /// Resuelve conflicto offline: conserva local (fuerza push) o adopta remoto.
  Future<Quote> resolveQuoteConflict({
    required String quoteId,
    required bool keepLocal,
  }) async {
    final orgId = _orgId;
    if (orgId == null || orgId.isEmpty) {
      throw Exception('Se requiere organización.');
    }
    final local = await OfflineLocalStore.instance.getQuote(
      organizationId: orgId,
      uid: _uid,
      quoteId: quoteId,
    );
    if (local == null) {
      throw Exception('No hay versión local del conflicto.');
    }
    if (keepLocal) {
      final pushed = await saveQuoteRemoteOnly(local.quote, isNew: false);
      await OfflineLocalStore.instance.markQuoteStatus(
        organizationId: orgId,
        uid: _uid,
        quoteId: quoteId,
        status: OfflineSyncStatus.synced,
      );
      await OfflineController.instance.refresh();
      return pushed;
    }
    final remote = await OrgQuoteRepository.instance.getQuote(
      orgId: orgId,
      quoteId: quoteId,
      session: _auth?.restSession,
    );
    if (remote == null) {
      throw Exception('No se pudo leer la versión remota.');
    }
    await OfflineLocalStore.instance.upsertQuote(
      uid: _uid,
      quote: remote,
      status: OfflineSyncStatus.synced,
    );
    await OfflineController.instance.refresh();
    return remote;
  }

  Future<List<Cotizacion>> _obtenerLegacy() async {
    if (_useRest) {
      final session = _auth?.restSession;
      if (session == null) return [];
      return FirestoreRestClient.instance.listCotizaciones(session);
    }
    final snap = await _legacyCol.orderBy('updatedAt', descending: true).get();
    return snap.docs.map((d) => _fromDoc(d.data())).toList();
  }

  Future<void> eliminarCotizacion(String id) async {
    final orgId = _orgId;
    if (orgId != null && orgId.isNotEmpty) {
      try {
        await OrgQuoteRepository.instance.deleteQuote(
          orgId: orgId,
          quoteId: id,
          session: _auth?.restSession,
        );
      } catch (e, st) {
        debugPrint('eliminar org quote: $e\n$st');
      }
    }

    if (_useRest) {
      await FirestoreRestClient.instance.deleteCotizacion(
        _auth!.restSession!,
        id,
      );
      return;
    }
    await _legacyCol.doc(id).delete();
  }

  Cotizacion _fromDoc(Map<String, dynamic> data) {
    final serviciosRaw = (data['servicios'] as List<dynamic>?) ?? [];
    final servicios = serviciosRaw
        .map((e) => Servicio.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    final map = Map<String, dynamic>.from(data);
    map.remove('servicios');
    map.remove('userId');
    map.remove('updatedAt');
    return Cotizacion.fromMap(map, servicios);
  }

  Future<int> getProximoNumero() async {
    final orgId = _orgId;
    if (orgId != null && orgId.isNotEmpty && !_useRest) {
      final snap = await _firestore
          .collection('organizations')
          .doc(orgId)
          .collection('counters')
          .doc('quotes')
          .get();
      final seq = (snap.data()?['seq'] as num?)?.toInt() ?? 0;
      return seq + 1;
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('ultimo_numero_cotizacion_$_uid') ?? 1;
  }

  Future<void> incrementarNumero() async {
    // Con org, la reserva atómica ocurre en insertarCotizacion.
    if (_orgId != null && _orgId!.isNotEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final key = 'ultimo_numero_cotizacion_$_uid';
    final actual = prefs.getInt(key) ?? 1;
    await prefs.setInt(key, actual + 1);
  }

  Future<void> configurarNumero(int nuevoValor) async {
    final orgId = _orgId;
    if (orgId != null && orgId.isNotEmpty) {
      if (_useRest) {
        final session = _auth?.restSession;
        if (session == null) return;
        await FirestoreRestClient.instance.upsertDocument(
          session: session,
          path: 'organizations/$orgId/counters/quotes',
          data: {
            'seq': nuevoValor <= 1 ? 0 : nuevoValor - 1,
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
          },
        );
        return;
      }
      await _firestore
          .collection('organizations')
          .doc(orgId)
          .collection('counters')
          .doc('quotes')
          .set({
            'seq': nuevoValor <= 1 ? 0 : nuevoValor - 1,
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
          }, SetOptions(merge: true));
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('ultimo_numero_cotizacion_$_uid', nuevoValor);
  }

  Future<String> getPrefijo() async {
    final org = _auth?.organization;
    if (org != null) return org.quotePrefix;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('prefijo_cotizacion_$_uid') ?? 'COT';
  }

  Future<void> configurarPrefijo(String prefijo) async {
    final orgId = _orgId;
    if (orgId != null && orgId.isNotEmpty) {
      if (_useRest) {
        final session = _auth?.restSession;
        if (session == null) return;
        final org = await OrganizationService.instance.getOrganization(
          orgId,
          session: session,
        );
        if (org == null) return;
        await FirestoreRestClient.instance.upsertDocument(
          session: session,
          path: 'organizations/$orgId',
          data: org.toMap()
            ..['quotePrefix'] = prefijo
            ..['updatedAt'] = DateTime.now().toUtc().toIso8601String(),
        );
        return;
      }
      await _firestore.collection('organizations').doc(orgId).set({
        'quotePrefix': prefijo,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      }, SetOptions(merge: true));
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('prefijo_cotizacion_$_uid', prefijo);
  }

  /// Guarda dominio [Quote]: primero local persistente; luego Firebase si hay red.
  Future<Quote> saveQuote(Quote quote, {required bool isNew}) async {
    final access = _auth?.access;
    final max = access?.maxCotizaciones ?? 5;
    if (isNew) {
      final actuales = await obtenerTodas();
      if (actuales.length >= max) {
        throw Exception(
          'Límite del plan ${access?.effectivePlan.label ?? 'Free'}: máximo $max cotizaciones. '
          'Actualiza a Pro para continuar.',
        );
      }
    }

    final orgId = _orgId;
    if (orgId == null || orgId.isEmpty) {
      final cot = QuoteMapper.toCotizacion(quote);
      await _upsertLegacy(cot);
      return quote;
    }

    final session = _auth?.restSession;
    final online = await ConnectivityMonitor.instance.probeFirebase();

    var toSave = quote.copyWith(organizationId: orgId);
    if (isNew && toSave.sequence <= 0) {
      if (online) {
        try {
          final org = await OrganizationService.instance.getOrganization(
            orgId,
            session: session,
          );
          final allocated = await OrgQuoteRepository.instance.allocateNumber(
            orgId: orgId,
            prefix: org?.quotePrefix ?? 'COT',
            session: session,
          );
          toSave = toSave.copyWith(
            sequence: allocated.sequence,
            number: allocated.number,
          );
        } catch (e) {
          debugPrint('allocateNumber offline fallback: $e');
          toSave = _withLocalProvisionalNumber(toSave);
        }
      } else {
        toSave = _withLocalProvisionalNumber(toSave);
      }
    }

    toSave = toSave
        .copyWith(
          updatedByUid: _uid,
          legacyUserPath: 'users/$_uid/cotizaciones/${toSave.id}',
          updatedAt: DateTime.now().toUtc(),
        )
        .withRecalculatedTotal();

    // Persistencia local inmediata (no depende de Firebase).
    try {
      await OfflineLocalStore.instance.upsertQuote(
        uid: _uid,
        quote: toSave,
        status: OfflineSyncStatus.pending,
      );
    } catch (e, st) {
      debugPrint('offline quote save: $e\n$st');
      if (!online) rethrow;
    }

    if (!online) {
      await _enqueueQuoteSync(toSave, isNew: isNew);
      await OfflineController.instance.refresh();
      return toSave;
    }

    try {
      await OrgQuoteRepository.instance.requireWritableOrg(
        orgId: orgId,
        uid: _uid,
        session: session,
      );

      // Conflicto: remoto más nuevo con distinta versión.
      final remote = await OrgQuoteRepository.instance.getQuote(
        orgId: orgId,
        quoteId: toSave.id,
        session: session,
      );
      if (remote != null &&
          !isNew &&
          remote.updatedAt.isAfter(toSave.updatedAt) &&
          remote.version != toSave.version) {
        final conflictMeta =
            '{"remoteUpdatedAt":"${remote.updatedAt.toIso8601String()}",'
            '"remoteVersion":${remote.version},"remoteNumber":"${remote.number}"}';
        await OfflineLocalStore.instance.upsertQuote(
          uid: _uid,
          quote: toSave,
          status: OfflineSyncStatus.conflict,
          conflictPayloadJson: conflictMeta,
        );
        throw Exception(
          'Conflicto de sincronización: esta cotización cambió en otro dispositivo. '
          'Revisa ambas versiones antes de sobrescribir.',
        );
      }

      await saveQuoteRemoteOnly(toSave, isNew: isNew);
      await OfflineLocalStore.instance.markQuoteStatus(
        organizationId: orgId,
        uid: _uid,
        quoteId: toSave.id,
        status: OfflineSyncStatus.synced,
      );
      await OfflineController.instance.refresh();
      return toSave;
    } catch (e) {
      if (e.toString().contains('Conflicto de sincronización')) rethrow;
      debugPrint('saveQuote remote failed, queued: $e');
      await _enqueueQuoteSync(toSave, isNew: isNew);
      await OfflineController.instance.refresh();
      return toSave;
    }
  }

  Quote _withLocalProvisionalNumber(Quote quote) {
    final short = quote.id.length >= 8
        ? quote.id.substring(0, 8).toUpperCase()
        : quote.id.toUpperCase();
    return quote.copyWith(sequence: 0, number: 'LOCAL-$short');
  }

  Future<void> _enqueueQuoteSync(Quote quote, {required bool isNew}) async {
    final payload = quote.toMap()..['__isNew'] = isNew;
    await OfflineLocalStore.instance.enqueue(
      organizationId: quote.organizationId,
      uid: _uid,
      entityType: OfflineEntityType.quote,
      entityId: quote.id,
      operation: OfflineOperation.upsert,
      payload: payload,
      idempotencyKey: OfflineSyncService.idempotencyKey(
        type: OfflineEntityType.quote,
        entityId: quote.id,
        op: OfflineOperation.upsert,
        revision: quote.updatedAt.toUtc().toIso8601String(),
      ),
    );
  }

  /// Escritura remota pura (usada por la cola de sync; no re-encola).
  Future<Quote> saveQuoteRemoteOnly(Quote quote, {required bool isNew}) async {
    final orgId = quote.organizationId;
    final session = _auth?.restSession;

    var toSave = quote;
    if (isNew &&
        (toSave.sequence <= 0 || toSave.number.startsWith('LOCAL-'))) {
      final org = await OrganizationService.instance.getOrganization(
        orgId,
        session: session,
      );
      final allocated = await OrgQuoteRepository.instance.allocateNumber(
        orgId: orgId,
        prefix: org?.quotePrefix ?? 'COT',
        session: session,
      );
      toSave = toSave.copyWith(
        sequence: allocated.sequence,
        number: allocated.number,
      );
    }

    toSave = toSave.withRecalculatedTotal();
    await OrgQuoteRepository.instance.upsertQuote(toSave, session: session);

    try {
      await ActivityRepository.instance.append(
        organizationId: orgId,
        type: isNew ? 'quote_created' : 'quote_updated',
        actorUid: _uid,
        message: isNew
            ? 'Cotización creada ${toSave.number}'
            : 'Cotización actualizada ${toSave.number}',
        entityType: 'quote',
        entityId: toSave.id,
        metadata: {
          'number': toSave.number,
          'status': toSave.status.id,
          'totalCents': toSave.total.cents,
        },
        session: session,
      );
      AppLogger.instance.info(
        isNew ? 'quote_created' : 'quote_updated',
        fields: {'orgId': orgId, 'quoteId': toSave.id},
      );
    } catch (e, st) {
      debugPrint('activity quote save: $e\n$st');
    }

    try {
      await _upsertLegacy(QuoteMapper.toCotizacion(toSave));
    } catch (e, st) {
      debugPrint('dual-write legacy quote: $e\n$st');
    }

    await OfflineLocalStore.instance.upsertQuote(
      uid: _uid,
      quote: toSave,
      status: OfflineSyncStatus.synced,
    );
    return toSave;
  }

  /// Lectura remota pura (cola de sync / detección de conflictos).
  Future<Quote?> getQuoteRemoteOnly(String quoteId) async {
    final orgId = _orgId;
    if (orgId == null || orgId.isEmpty) return null;
    return OrgQuoteRepository.instance.getQuote(
      orgId: orgId,
      quoteId: quoteId,
      session: _auth?.restSession,
    );
  }

  Future<Quote?> getQuote(String quoteId) async {
    final orgId = _orgId;
    if (orgId == null || orgId.isEmpty) return null;

    LocalQuoteRecord? local;
    try {
      local = await OfflineLocalStore.instance.getQuote(
        organizationId: orgId,
        uid: _uid,
        quoteId: quoteId,
      );
    } catch (_) {}

    try {
      final remote = await OrgQuoteRepository.instance.getQuote(
        orgId: orgId,
        quoteId: quoteId,
        session: _auth?.restSession,
      );
      if (remote != null) {
        if (local != null &&
            (local.syncStatus == OfflineSyncStatus.pending ||
                local.syncStatus == OfflineSyncStatus.conflict ||
                local.quote.updatedAt.isAfter(remote.updatedAt))) {
          return local.quote;
        }
        return remote;
      }
    } catch (e) {
      debugPrint('getQuote remote: $e');
    }
    return local?.quote;
  }

  Future<Quote> duplicateQuote(String quoteId) async {
    final orgId = _orgId;
    if (orgId == null || orgId.isEmpty) {
      throw Exception('Se requiere organización para duplicar.');
    }
    final existing = await getQuote(quoteId);
    if (existing == null) {
      throw Exception('Cotización no encontrada.');
    }
    final access = _auth?.access;
    final max = access?.maxCotizaciones ?? 5;
    final actuales = await obtenerTodas();
    if (actuales.length >= max) {
      throw Exception('Límite del plan: máximo $max cotizaciones.');
    }
    final prefix = await getPrefijo();
    final copy = await OrgQuoteRepository.instance.duplicateQuote(
      source: existing,
      prefix: prefix,
      createdByUid: _uid,
      session: _auth?.restSession,
    );
    try {
      await _upsertLegacy(QuoteMapper.toCotizacion(copy));
    } catch (e, st) {
      debugPrint('dual-write duplicate: $e\n$st');
    }
    return copy;
  }

  Future<Quote> createQuoteVersion(String quoteId) async {
    final orgId = _orgId;
    if (orgId == null || orgId.isEmpty) {
      throw Exception('Se requiere organización para versionar.');
    }
    final existing = await getQuote(quoteId);
    if (existing == null) {
      throw Exception('Cotización no encontrada.');
    }
    final next = await OrgQuoteRepository.instance.createVersion(
      source: existing,
      createdByUid: _uid,
      session: _auth?.restSession,
    );
    try {
      await _upsertLegacy(QuoteMapper.toCotizacion(next));
    } catch (e, st) {
      debugPrint('dual-write version: $e\n$st');
    }
    return next;
  }

  Future<Quote> setQuoteStatus(String quoteId, QuoteStatus status) async {
    final orgId = _orgId;
    if (orgId == null || orgId.isEmpty) {
      throw Exception('Se requiere organización para cambiar estado.');
    }
    final existing = await getQuote(quoteId);
    if (existing == null) {
      throw Exception('Cotización no encontrada.');
    }
    final updated = await OrgQuoteRepository.instance.updateStatus(
      quote: existing,
      status: status,
      session: _auth?.restSession,
    );
    await ActivityRepository.instance.append(
      organizationId: orgId,
      type: 'quote_status_changed',
      actorUid: _uid,
      message: '${existing.number}: ${existing.status.id} → ${status.id}',
      entityType: 'quote',
      entityId: quoteId,
      metadata: {'from': existing.status.id, 'to': status.id},
      session: _auth?.restSession,
    );
    AppLogger.instance.info(
      'quote_status_changed',
      fields: {
        'orgId': orgId,
        'quoteId': quoteId,
        'from': existing.status.id,
        'to': status.id,
      },
    );
    return updated;
  }
}
