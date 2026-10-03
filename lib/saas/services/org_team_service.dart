import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../config/saas_platform.dart';
import '../domain/org_enums.dart';
import '../models/org_activity.dart';
import '../models/organization.dart';
import 'activity_repository.dart';
import 'app_logger.dart';
import 'auth_service.dart';
import 'firestore_rest_client.dart';
import 'identity_toolkit_client.dart';
import 'organization_service.dart';

/// Miembros e invitaciones de organización.
class OrgTeamService {
  OrgTeamService._();
  static final OrgTeamService instance = OrgTeamService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  Future<List<OrgMembership>> listOrgMembers({
    required String orgId,
    AuthSession? session,
  }) async {
    if (saasUseRestBackend || session != null) {
      final s = session ?? AuthService.instance.restSession;
      if (s == null) return [];
      final rows = await FirestoreRestClient.instance.listCollection(
        session: s,
        path: 'organizations/$orgId/members',
      );
      return rows.map(OrgMembership.fromMap).toList();
    }
    final snap = await _db
        .collection('organizations')
        .doc(orgId)
        .collection('members')
        .get();
    return snap.docs.map((d) => OrgMembership.fromMap(d.data())).toList();
  }

  Future<List<OrgInvite>> listInvites({
    required String orgId,
    AuthSession? session,
  }) async {
    if (saasUseRestBackend || session != null) {
      final s = session ?? AuthService.instance.restSession;
      if (s == null) return [];
      try {
        final rows = await FirestoreRestClient.instance.listCollection(
          session: s,
          path: 'organizations/$orgId/invites',
        );
        return rows
            .map(OrgInvite.fromMap)
            .where((i) => i.status == 'pending')
            .toList();
      } catch (e, st) {
        debugPrint('listInvites REST: $e\n$st');
        return [];
      }
    }
    final snap = await _db
        .collection('organizations')
        .doc(orgId)
        .collection('invites')
        .where('status', isEqualTo: 'pending')
        .get();
    return snap.docs.map((d) => OrgInvite.fromMap(d.data())).toList();
  }

  /// Crea invitación por correo. El invitado la acepta con [acceptInvite].
  Future<OrgInvite> inviteMember({
    required String orgId,
    required String email,
    required OrgRole role,
    required String invitedByUid,
    required int maxSeats,
    AuthSession? session,
  }) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty || !normalized.contains('@')) {
      throw Exception('Correo de invitación inválido');
    }
    if (role == OrgRole.owner) {
      throw Exception('No se puede invitar como owner');
    }

    // UX temprana: el cupo autoritativo se revalida en acceptOrgInvite (Function).
    final members = await listOrgMembers(orgId: orgId, session: session);
    final active = members
        .where((m) => m.status == MembershipStatus.active)
        .length;
    final pending = await listInvites(orgId: orgId, session: session);
    if (maxSeats < 1 || active + pending.length >= maxSeats) {
      throw Exception(
        'Límite de asientos ($maxSeats). Mejora el plan o libera un miembro.',
      );
    }

    final now = DateTime.now().toUtc();
    final id = const Uuid().v4();
    final token = const Uuid().v4().replaceAll('-', '');
    final invite = OrgInvite(
      id: id,
      organizationId: orgId,
      email: normalized,
      role: role.id,
      invitedByUid: invitedByUid,
      token: token,
      expiresAt: now.add(const Duration(days: 7)),
      createdAt: now,
    );

    if (saasUseRestBackend || session != null) {
      final s = session ?? AuthService.instance.restSession;
      if (s == null) throw Exception('Sesión no disponible');
      await FirestoreRestClient.instance.upsertDocument(
        session: s,
        path: 'organizations/$orgId/invites/$id',
        data: invite.toMap(),
      );
    } else {
      await _db
          .collection('organizations')
          .doc(orgId)
          .collection('invites')
          .doc(id)
          .set(invite.toMap());
    }

    await ActivityRepository.instance.append(
      organizationId: orgId,
      type: 'member_invited',
      actorUid: invitedByUid,
      message: 'Invitación a $normalized ($role)',
      entityType: 'invite',
      entityId: id,
      metadata: {'email': normalized, 'role': role.id},
      session: session,
    );
    AppLogger.instance.info(
      'member_invited',
      fields: {'orgId': orgId, 'email': normalized, 'role': role.id},
    );
    return invite;
  }

  Future<void> updateMemberRole({
    required String orgId,
    required String memberUid,
    required OrgRole role,
    required String actorUid,
    AuthSession? session,
  }) async {
    if (role == OrgRole.owner) {
      throw Exception('No se puede asignar owner desde aquí');
    }
    final member = await OrganizationService.instance.getMembership(
      orgId: orgId,
      uid: memberUid,
      session: session,
    );
    if (member == null) throw Exception('Miembro no encontrado');
    if (member.role == OrgRole.owner) {
      throw Exception('No se puede cambiar el rol del owner');
    }

    final updated = OrgMembership(
      organizationId: orgId,
      uid: memberUid,
      role: role,
      status: member.status,
      displayName: member.displayName,
      email: member.email,
      createdAt: member.createdAt,
      updatedAt: DateTime.now().toUtc(),
    );

    await _writeMember(orgId, updated, session: session);
    await ActivityRepository.instance.append(
      organizationId: orgId,
      type: 'member_role_updated',
      actorUid: actorUid,
      message: 'Rol de $memberUid → ${role.id}',
      entityType: 'member',
      entityId: memberUid,
      metadata: {'role': role.id},
      session: session,
    );
  }

  Future<void> disableMember({
    required String orgId,
    required String memberUid,
    required String actorUid,
    AuthSession? session,
  }) async {
    final member = await OrganizationService.instance.getMembership(
      orgId: orgId,
      uid: memberUid,
      session: session,
    );
    if (member == null) throw Exception('Miembro no encontrado');
    if (member.role == OrgRole.owner) {
      throw Exception('No se puede desactivar al owner');
    }
    final updated = OrgMembership(
      organizationId: orgId,
      uid: memberUid,
      role: member.role,
      status: MembershipStatus.disabled,
      displayName: member.displayName,
      email: member.email,
      createdAt: member.createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
    await _writeMember(orgId, updated, session: session);
    await ActivityRepository.instance.append(
      organizationId: orgId,
      type: 'member_disabled',
      actorUid: actorUid,
      message: 'Miembro desactivado: $memberUid',
      entityType: 'member',
      entityId: memberUid,
      session: session,
    );
  }

  /// Acepta invitación vía Cloud Function (Admin SDK crea la membresía).
  Future<void> acceptInvite({required String token}) async {
    if (saasUseRestBackend) {
      // REST desktop: aceptar en cliente si hay invite + sesión.
      await _acceptInviteRest(token);
      return;
    }
    final callable = FirebaseFunctions.instance.httpsCallable(
      'acceptOrgInvite',
    );
    await callable.call(<String, dynamic>{'token': token});
    AppLogger.instance.info(
      'invite_accepted',
      fields: {'tokenPrefix': token.substring(0, 6)},
    );
  }

  Future<void> _acceptInviteRest(String token) async {
    final session = AuthService.instance.restSession;
    if (session == null) throw Exception('Sesión no disponible');
    // Buscar invite por token requiere collection group; usamos Function HTTP si existe,
    // o el usuario pega orgId+inviteId. Fallback: callable no disponible en REST.
    throw Exception(
      'En escritorio acepta la invitación desde Web/Android, o pide al admin que te agregue.',
    );
  }

  Future<void> _writeMember(
    String orgId,
    OrgMembership member, {
    AuthSession? session,
  }) async {
    if (saasUseRestBackend || session != null) {
      final s = session ?? AuthService.instance.restSession;
      if (s == null) throw Exception('Sesión no disponible');
      await FirestoreRestClient.instance.upsertDocument(
        session: s,
        path: 'organizations/$orgId/members/${member.uid}',
        data: member.toMap(),
      );
      await FirestoreRestClient.instance.upsertDocument(
        session: s,
        path: 'users/${member.uid}/memberships/$orgId',
        data: member.toMap(),
      );
      return;
    }
    final batch = _db.batch();
    batch.set(
      _db
          .collection('organizations')
          .doc(orgId)
          .collection('members')
          .doc(member.uid),
      member.toMap(),
    );
    batch.set(
      _db
          .collection('users')
          .doc(member.uid)
          .collection('memberships')
          .doc(orgId),
      member.toMap(),
    );
    await batch.commit();
  }
}
