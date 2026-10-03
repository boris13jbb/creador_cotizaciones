import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../config/saas_platform.dart';
import '../models/org_activity.dart';
import 'auth_service.dart';
import 'firestore_rest_client.dart';
import 'identity_toolkit_client.dart';

/// Auditoría append-only por organización.
class ActivityRepository {
  ActivityRepository._();
  static final ActivityRepository instance = ActivityRepository._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  Future<void> append({
    required String organizationId,
    required String type,
    required String actorUid,
    required String message,
    String? actorEmail,
    String? entityType,
    String? entityId,
    Map<String, dynamic> metadata = const {},
    AuthSession? session,
  }) async {
    if (organizationId.isEmpty || actorUid.isEmpty) return;
    final now = DateTime.now().toUtc();
    final id = const Uuid().v4();
    final activity = OrgActivity(
      id: id,
      organizationId: organizationId,
      type: type,
      actorUid: actorUid,
      actorEmail: actorEmail,
      entityType: entityType,
      entityId: entityId,
      message: message,
      metadata: metadata,
      createdAt: now,
    );

    try {
      if (saasUseRestBackend || session != null) {
        final s = session ?? AuthService.instance.restSession;
        if (s == null) return;
        await FirestoreRestClient.instance.upsertDocument(
          session: s,
          path: 'organizations/$organizationId/activities/$id',
          data: activity.toMap(),
        );
        return;
      }
      await _db
          .collection('organizations')
          .doc(organizationId)
          .collection('activities')
          .doc(id)
          .set(activity.toMap());
    } catch (e, st) {
      debugPrint('ActivityRepository.append: $e\n$st');
    }
  }

  Future<List<OrgActivity>> listRecent({
    required String organizationId,
    int limit = 30,
    AuthSession? session,
  }) async {
    if (saasUseRestBackend || session != null) {
      final s = session ?? AuthService.instance.restSession;
      if (s == null) return [];
      try {
        final rows = await FirestoreRestClient.instance.listCollection(
          session: s,
          path: 'organizations/$organizationId/activities',
        );
        final list = rows.map(OrgActivity.fromMap).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list.take(limit).toList();
      } catch (e, st) {
        debugPrint('listRecent activities REST: $e\n$st');
        return [];
      }
    }

    final snap = await _db
        .collection('organizations')
        .doc(organizationId)
        .collection('activities')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => OrgActivity.fromMap(d.data())).toList();
  }
}
