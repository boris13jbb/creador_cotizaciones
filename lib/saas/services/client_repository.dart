import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../config/saas_platform.dart';
import '../models/org_client.dart';
import 'auth_service.dart';
import 'firestore_rest_client.dart';

class ClientRepository {
  ClientRepository._();
  static final ClientRepository instance = ClientRepository._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  bool get _useRest => saasUseRestBackend;

  Future<OrgClient> upsert({
    required String organizationId,
    required OrgClient client,
  }) async {
    final now = DateTime.now().toUtc();
    final data = client
        .copyWith(
          id: client.id.isEmpty ? const Uuid().v4() : client.id,
          updatedAt: now,
        )
        .toMap();
    data['organizationId'] = organizationId;

    if (_useRest) {
      final session = AuthService.instance.restSession;
      if (session == null) throw Exception('Sesión no disponible');
      await FirestoreRestClient.instance.upsertDocument(
        session: session,
        path: 'organizations/$organizationId/clients/${data['id']}',
        data: data,
      );
      return OrgClient.fromMap(data);
    }

    await _db
        .collection('organizations')
        .doc(organizationId)
        .collection('clients')
        .doc(data['id'] as String)
        .set(data, SetOptions(merge: true));
    return OrgClient.fromMap(data);
  }

  Future<List<OrgClient>> list(
    String organizationId, {
    int limit = 50,
    String? startAfterName,
  }) async {
    if (_useRest) {
      final session = AuthService.instance.restSession;
      if (session == null) return [];
      final maps = await FirestoreRestClient.instance.listCollection(
        session: session,
        path: 'organizations/$organizationId/clients',
        pageSize: limit,
      );
      final list = maps.map(OrgClient.fromMap).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      return list;
    }

    Query<Map<String, dynamic>> q = _db
        .collection('organizations')
        .doc(organizationId)
        .collection('clients')
        .orderBy('name');
    if (startAfterName != null) {
      q = q.startAfter([startAfterName]);
    }
    final snap = await q.limit(limit).get();
    return snap.docs.map((d) => OrgClient.fromMap(d.data())).toList();
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
