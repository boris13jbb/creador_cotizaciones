import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../config/saas_platform.dart';
import '../models/org_client.dart';
import '../offline/connectivity_monitor.dart';
import '../offline/offline_controller.dart';
import '../offline/offline_local_store.dart';
import '../offline/offline_sync_service.dart';
import '../offline/offline_sync_status.dart';
import 'auth_service.dart';
import 'firestore_rest_client.dart';

class ClientRepository {
  ClientRepository._();
  static final ClientRepository instance = ClientRepository._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  bool get _useRest => saasUseRestBackend;

  String? get _uid {
    try {
      final rest = AuthService.instance.restSession?.uid;
      if (rest != null && rest.isNotEmpty) return rest;
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return AuthService.instance.restSession?.uid;
    }
  }

  Future<OrgClient> upsert({
    required String organizationId,
    required OrgClient client,
    bool skipOfflineMirror = false,
  }) async {
    final now = DateTime.now().toUtc();
    final prepared = client.copyWith(
      id: client.id.isEmpty ? const Uuid().v4() : client.id,
      updatedAt: now,
    );
    final data = prepared.toMap();
    data['organizationId'] = organizationId;
    final result = OrgClient.fromMap(data);
    final uid = _uid;

    if (!skipOfflineMirror && uid != null) {
      try {
        await OfflineLocalStore.instance.upsertClient(
          uid: uid,
          client: result,
          status: OfflineSyncStatus.pending,
        );
      } catch (e) {
        debugPrint('offline client mirror: $e');
      }
    }

    final online =
        ConnectivityMonitor.instance.isEffectivelyOnline ||
        await ConnectivityMonitor.instance.probeFirebase();

    if (!online) {
      if (!OfflineLocalStore.isSupported) {
        throw Exception(
          'Sin conexión. En Web no hay cola offline; reintenta cuando haya red.',
        );
      }
      if (uid != null) {
        await OfflineLocalStore.instance.enqueue(
          organizationId: organizationId,
          uid: uid,
          entityType: OfflineEntityType.client,
          entityId: result.id,
          operation: OfflineOperation.upsert,
          payload: result.toMap(),
          idempotencyKey: OfflineSyncService.idempotencyKey(
            type: OfflineEntityType.client,
            entityId: result.id,
            op: OfflineOperation.upsert,
            revision: result.updatedAt.toUtc().toIso8601String(),
          ),
        );
        await OfflineController.instance.refresh();
      }
      return result;
    }

    try {
      if (_useRest) {
        final session = AuthService.instance.restSession;
        if (session == null) throw Exception('Sesión no disponible');
        await FirestoreRestClient.instance.upsertDocument(
          session: session,
          path: 'organizations/$organizationId/clients/${data['id']}',
          data: data,
        );
      } else {
        await _db
            .collection('organizations')
            .doc(organizationId)
            .collection('clients')
            .doc(data['id'] as String)
            .set(data, SetOptions(merge: true));
      }
      if (!skipOfflineMirror && uid != null) {
        await OfflineLocalStore.instance.markClientStatus(
          organizationId: organizationId,
          uid: uid,
          clientId: result.id,
          status: OfflineSyncStatus.synced,
        );
      }
      return result;
    } catch (e) {
      if (uid != null &&
          !skipOfflineMirror &&
          OfflineLocalStore.isSupported) {
        await OfflineLocalStore.instance.enqueue(
          organizationId: organizationId,
          uid: uid,
          entityType: OfflineEntityType.client,
          entityId: result.id,
          operation: OfflineOperation.upsert,
          payload: result.toMap(),
          idempotencyKey: OfflineSyncService.idempotencyKey(
            type: OfflineEntityType.client,
            entityId: result.id,
            op: OfflineOperation.upsert,
            revision: result.updatedAt.toUtc().toIso8601String(),
          ),
        );
        await OfflineController.instance.refresh();
        return result;
      }
      rethrow;
    }
  }

  Future<List<OrgClient>> list(
    String organizationId, {
    int limit = 50,
    String? startAfterName,
  }) async {
    final uid = _uid;
    List<OrgClient> remote = [];
    final online = ConnectivityMonitor.instance.isEffectivelyOnline;

    if (online) {
      try {
        if (_useRest) {
          final session = AuthService.instance.restSession;
          if (session != null) {
            final maps = await FirestoreRestClient.instance.listCollection(
              session: session,
              path: 'organizations/$organizationId/clients',
              pageSize: limit,
            );
            remote = maps.map(OrgClient.fromMap).toList();
          }
        } else {
          Query<Map<String, dynamic>> q = _db
              .collection('organizations')
              .doc(organizationId)
              .collection('clients')
              .orderBy('name');
          if (startAfterName != null) {
            q = q.startAfter([startAfterName]);
          }
          final snap = await q.limit(limit).get();
          remote = snap.docs.map((d) => OrgClient.fromMap(d.data())).toList();
        }
        if (uid != null) {
          for (final c in remote) {
            await OfflineLocalStore.instance.upsertClient(
              uid: uid,
              client: c,
              status: OfflineSyncStatus.synced,
            );
          }
        }
      } catch (e) {
        debugPrint('client list remote: $e');
      }
    }

    if (uid != null) {
      try {
        final local = await OfflineLocalStore.instance.listClients(
          organizationId: organizationId,
          uid: uid,
        );
        final byId = <String, OrgClient>{for (final c in remote) c.id: c};
        for (final c in local) {
          final existing = byId[c.id];
          if (existing == null ||
              c.updatedAt.isAfter(existing.updatedAt) ||
              !online) {
            byId[c.id] = c;
          }
        }
        final merged = byId.values.toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        return merged.take(limit).toList();
      } catch (e) {
        debugPrint('client list local: $e');
      }
    }

    remote.sort((a, b) => a.name.compareTo(b.name));
    return remote.take(limit).toList();
  }

  Future<void> delete(String organizationId, String clientId) async {
    if (_useRest) {
      final session = AuthService.instance.restSession;
      if (session == null) return;
      await FirestoreRestClient.instance.deleteDocument(
        session: session,
        path: 'organizations/$organizationId/clients/$clientId',
      );
      return;
    }
    await _db
        .collection('organizations')
        .doc(organizationId)
        .collection('clients')
        .doc(clientId)
        .delete();
  }
}

extension on OrgClient {
  OrgClient copyWith({String? id, DateTime? updatedAt}) {
    return OrgClient(
      id: id ?? this.id,
      organizationId: organizationId,
      name: name,
      identification: identification,
      email: email,
      phone: phone,
      address: address,
      city: city,
      country: country,
      notes: notes,
      contacts: contacts,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
