import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../config/saas_platform.dart';
import '../domain/org_enums.dart';
import '../models/organization.dart';
import '../models/saas_user_profile.dart';
import 'auth_service.dart';
import 'firestore_rest_client.dart';
import 'identity_toolkit_client.dart';

/// Bootstrap y lectura de organizaciones / membresías.
class OrganizationService {
  OrganizationService._();
  static final OrganizationService instance = OrganizationService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  bool get _useRest => saasUseRestBackend;

  /// Busca organización ya vinculada (perfil o membresías). No crea nada.
  Future<Organization?> findExistingOrganization({
    required String uid,
    String? existingOrgId,
    AuthSession? session,
  }) async {
    if (existingOrgId != null && existingOrgId.isNotEmpty) {
      final org = await getOrganization(existingOrgId, session: session);
      if (org != null) return org;
    }
    final memberships = await listMemberships(uid, session: session);
    if (memberships.isEmpty) return null;
    return getOrganization(memberships.first.organizationId, session: session);
  }

  /// Persiste `defaultOrganizationId` en el perfil del usuario.
  Future<void> linkDefaultOrganization({
    required String uid,
    required String orgId,
    required String email,
    required String displayName,
    AuthSession? session,
  }) =>
      _linkDefaultOrg(
        uid: uid,
        orgId: orgId,
        email: email,
        displayName: displayName,
        session: session,
      );

  /// Crea organización personal + membresía owner si no existe.
  ///
  /// Las escrituras van en secuencia (no batch): las rules de counters/
  /// clientes requieren membresía ya visible, y un batch no la ve.
  Future<Organization> ensurePersonalOrganization({
    required String uid,
    required String displayName,
    required String email,
    String? existingOrgId,
    String? organizationName,
    AuthSession? session,
  }) async {
    final existing = await findExistingOrganization(
      uid: uid,
      existingOrgId: existingOrgId,
      session: session,
    );
    if (existing != null) {
      await _linkDefaultOrg(
        uid: uid,
        orgId: existing.id,
        email: email,
        displayName: displayName,
        session: session,
      );
      return existing;
    }

    final trimmedName = (organizationName ?? '').trim();
    final now = DateTime.now().toUtc();
    final orgId = const Uuid().v4();
    final org = Organization(
      id: orgId,
      name: trimmedName.isNotEmpty
          ? trimmedName
          : (displayName.isNotEmpty ? '$displayName — Empresa' : 'Mi empresa'),
      currency: 'USD',
      quotePrefix: 'COT',
      ownerUid: uid,
      createdAt: now,
      updatedAt: now,
    );
    final member = OrgMembership(
      organizationId: orgId,
      uid: uid,
      role: OrgRole.owner,
      status: MembershipStatus.active,
      displayName: displayName,
      email: email,
      createdAt: now,
      updatedAt: now,
    );

    if (_useRest || session != null) {
      final s = session ?? AuthService.instance.restSession;
      if (s == null) throw Exception('Sesión no disponible');
      await FirestoreRestClient.instance.createDocumentIfAbsent(
        session: s,
        path: 'organizations/$orgId',
        data: org.toMap(),
      );
      await FirestoreRestClient.instance.createDocumentIfAbsent(
        session: s,
        path: 'organizations/$orgId/members/$uid',
        data: member.toMap(),
      );
      await FirestoreRestClient.instance.createDocumentIfAbsent(
        session: s,
        path: 'organizations/$orgId/counters/quotes',
        data: {'seq': 0, 'updatedAt': now.toIso8601String()},
      );
      await FirestoreRestClient.instance.createDocumentIfAbsent(
        session: s,
        path: 'users/$uid/memberships/$orgId',
        data: member.toMap(),
      );
      await _linkDefaultOrg(
        uid: uid,
        orgId: orgId,
        email: email,
        displayName: displayName,
        session: s,
      );
      return org;
    }

    // Secuencia nativa: org → member → counter → membership → profile.
    await _db.collection('organizations').doc(orgId).set(org.toMap());
    await _db
        .collection('organizations')
        .doc(orgId)
        .collection('members')
        .doc(uid)
        .set(member.toMap());
    await _db
        .collection('organizations')
        .doc(orgId)
        .collection('counters')
        .doc('quotes')
        .set({'seq': 0, 'updatedAt': now.toIso8601String()});
    await _db
        .collection('users')
        .doc(uid)
        .collection('memberships')
        .doc(orgId)
        .set(member.toMap());
    await _linkDefaultOrg(
      uid: uid,
      orgId: orgId,
      email: email,
      displayName: displayName,
    );
    return org;
  }

  Future<void> _linkDefaultOrg({
    required String uid,
    required String orgId,
    required String email,
    required String displayName,
    AuthSession? session,
  }) async {
    final now = DateTime.now().toUtc();
    if (_useRest || session != null) {
      final s = session ?? AuthService.instance.restSession;
      if (s == null) return;
      await FirestoreRestClient.instance.upsertEditableProfile(
        session: s,
        profile: {
          'uid': uid,
          'email': email,
          'displayName': displayName,
          'defaultOrganizationId': orgId,
          'updatedAt': now.toIso8601String(),
        },
      );
      return;
    }
    await _db.collection('users').doc(uid).set({
      'defaultOrganizationId': orgId,
      'updatedAt': now.toIso8601String(),
    }, SetOptions(merge: true));
  }

  Future<Organization?> getOrganization(
    String orgId, {
    AuthSession? session,
  }) async {
    if (_useRest || session != null) {
      final s = session ?? AuthService.instance.restSession;
      if (s == null) return null;
      final map = await FirestoreRestClient.instance.getDocument(
        session: s,
        path: 'organizations/$orgId',
      );
      if (map == null) return null;
      return Organization.fromMap(map);
    }
    final snap = await _db.collection('organizations').doc(orgId).get();
    if (!snap.exists || snap.data() == null) return null;
    return Organization.fromMap(snap.data()!);
  }

  Future<List<OrgMembership>> listMemberships(
    String uid, {
    AuthSession? session,
  }) async {
    if (_useRest || session != null) {
      final s = session ?? AuthService.instance.restSession;
      if (s == null) return [];
      // Listado vía colección users/{uid}/memberships
      try {
        final res = await FirestoreRestClient.instance.listCollection(
          session: s,
          path: 'users/$uid/memberships',
        );
        return res.map(OrgMembership.fromMap).toList();
      } catch (e, st) {
        debugPrint('listMemberships REST: $e\n$st');
        return [];
      }
    }
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('memberships')
        .get();
    return snap.docs.map((d) => OrgMembership.fromMap(d.data())).toList();
  }

  Future<OrgMembership?> getMembership({
    required String orgId,
    required String uid,
    AuthSession? session,
  }) async {
    if (_useRest || session != null) {
      final s = session ?? AuthService.instance.restSession;
      if (s == null) return null;
      final map = await FirestoreRestClient.instance.getDocument(
        session: s,
        path: 'organizations/$orgId/members/$uid',
      );
      if (map == null) return null;
      return OrgMembership.fromMap(map);
    }
    final snap = await _db
        .collection('organizations')
        .doc(orgId)
        .collection('members')
        .doc(uid)
        .get();
    if (!snap.exists || snap.data() == null) return null;
    return OrgMembership.fromMap(snap.data()!);
  }

  String? orgIdFromProfile(SaasUserProfile? profile) =>
      profile?.defaultOrganizationId;
}
