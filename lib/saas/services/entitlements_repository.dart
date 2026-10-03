import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/saas_config.dart';
import '../config/saas_platform.dart';
import '../models/entitlements.dart';
import '../models/saas_user_profile.dart';
import 'auth_service.dart';
import 'entitlements_calculator.dart';
import 'firestore_rest_client.dart';
import 'identity_toolkit_client.dart';

/// Carga entitlements. El bootstrap (trial) solo lo escribe el backend.
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

    try {
      return await _ensureViaBackend(uid: uid, session: session);
    } catch (e, st) {
      debugPrint('ensureMyEntitlements falló: $e\n$st');
      final again = await _get(uid, session: session);
      if (again != null) return again;
    }

    // Fail-closed: no inventar trial Pro en memoria (C-02 / M-12).
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

    final now = DateTime.now().toUtc();
    return Entitlements(
      uid: uid,
      plan: SubscriptionPlan.free,
      subscriptionStatus: 'inactive',
      source: 'client_fallback',
      createdAt: now,
      updatedAt: now,
    );
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

  /// Bootstrap autoritativo vía Cloud Function (Admin SDK escribe trial).
  Future<Entitlements> _ensureViaBackend({
    required String uid,
    AuthSession? session,
  }) async {
    if (_useRest) {
      final s = session ?? AuthService.instance.restSession;
      if (s == null) throw Exception('Sesión REST no disponible');
      final projectId = Firebase.app().options.projectId;
      final base = SaasConfig.functionsBaseUrl.isNotEmpty
          ? SaasConfig.functionsBaseUrl
          : 'https://us-central1-$projectId.cloudfunctions.net';
      final uri = Uri.parse('$base/ensureMyEntitlements');
      final res = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer ${s.idToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'data': <String, dynamic>{}}),
      );
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception(
          'ensureMyEntitlements HTTP ${res.statusCode}: ${res.body}',
        );
      }
    } else {
      await FirebaseFunctions.instance
          .httpsCallable('ensureMyEntitlements')
          .call(<String, dynamic>{});
    }

    final created = await _get(uid, session: session);
    if (created == null) {
      throw Exception('Entitlements no disponibles tras bootstrap backend.');
    }
    return created;
  }

  EffectiveAccess evaluate(Entitlements? entitlements) =>
      EntitlementsService.instance.evaluate(entitlements);
}
