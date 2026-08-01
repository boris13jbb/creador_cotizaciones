import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../config/saas_platform.dart';
import '../models/entitlements.dart';
import '../models/saas_user_profile.dart';
import 'auth_service.dart';
import 'entitlements_calculator.dart';
import 'firestore_rest_client.dart';
import 'identity_toolkit_client.dart';

/// Carga y bootstrap de entitlements (lectura cliente + create inicial acotado por reglas).
class EntitlementsRepository {
  EntitlementsRepository._();
  static final EntitlementsRepository instance = EntitlementsRepository._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _ref(String uid) =>
      _db.collection('entitlements').doc(uid);

  bool get _useRest {
    if (saasUseRestBackend) return true;
    final rest = AuthService.instance.restSession;
    if (rest == null) return false;
    try {
      return FirebaseAuth.instance.currentUser == null;
    } catch (_) {
      return true;
    }
  }

  Future<Entitlements> loadForUser({
    required String uid,
    SaasUserProfile? profile,
    AuthSession? session,
  }) async {
    final existing = await _get(uid, session: session);
    if (existing != null) return existing;

    if (profile?.legacyPlan != null) {
      return Entitlements.fromLegacyProfile(
        uid: uid,
        plan: profile!.legacyPlan!,
        subscriptionStatus: profile.legacySubscriptionStatus ?? 'active',
        trialEndsAt: profile.legacyTrialEndsAt,
        createdAt: profile.createdAt,
        updatedAt: profile.updatedAt,
      );
    }

    final initial = Entitlements.initialTrial(uid);
    try {
      await _createInitial(initial, session: session);
      return initial;
    } catch (e, st) {
      debugPrint('No se pudo crear entitlements iniciales: $e\n$st');
      final again = await _get(uid, session: session);
      if (again != null) return again;
      return initial;
    }
  }

  Stream<Entitlements?> watch(String uid) {
    if (_useRest) {
      return Stream.fromFuture(
        _get(uid, session: AuthService.instance.restSession),
      );
    }
    return _ref(uid).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return Entitlements.fromMap(snap.data()!);
    });
  }

  Future<Entitlements?> _get(String uid, {AuthSession? session}) async {
    if (_useRest) {
      final s = session ?? AuthService.instance.restSession;
      if (s == null) return null;
      final map = await FirestoreRestClient.instance.getDocument(
        session: s,
        path: 'entitlements/$uid',
      );
      if (map == null) return null;
      return Entitlements.fromMap(map);
    }
    try {
      final snap = await _ref(uid).get();
      if (!snap.exists || snap.data() == null) return null;
      return Entitlements.fromMap(snap.data()!);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw Exception(
          'Sin permisos en Firestore (entitlements). Despliega firestore.rules '
          'en el proyecto cotiapp-saas-jb.',
        );
      }
      rethrow;
    }
  }

  Future<void> _createInitial(
    Entitlements entitlements, {
    AuthSession? session,
  }) async {
    if (_useRest) {
      final s = session ?? AuthService.instance.restSession;
      if (s == null) throw Exception('Sesión REST no disponible');
      await FirestoreRestClient.instance.createDocumentIfAbsent(
        session: s,
        path: 'entitlements/${entitlements.uid}',
        data: entitlements.toMap(),
      );
      return;
    }
    final ref = _ref(entitlements.uid);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (snap.exists) return;
      tx.set(ref, entitlements.toMap());
    });
  }

  EffectiveAccess evaluate(Entitlements? entitlements) =>
      EntitlementsService.instance.evaluate(entitlements);
}
