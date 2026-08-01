import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../config/saas_platform.dart';
import '../models/catalog_item.dart';
import 'auth_service.dart';
import 'firestore_rest_client.dart';

class CatalogRepository {
  CatalogRepository._();
  static final CatalogRepository instance = CatalogRepository._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  bool get _useRest => saasUseRestBackend;

  Future<CatalogItem> upsert({
    required String organizationId,
    required CatalogItem item,
  }) async {
    final now = DateTime.now().toUtc();
    final id = item.id.isEmpty ? const Uuid().v4() : item.id;
    final data = item.toMap()
      ..['id'] = id
      ..['organizationId'] = organizationId
      ..['updatedAt'] = now.toIso8601String();
    if (item.createdAt.isBefore(DateTime.utc(2000))) {
      data['createdAt'] = now.toIso8601String();
    }

    if (_useRest) {
      final session = AuthService.instance.restSession;
      if (session == null) throw Exception('Sesión no disponible');
      await FirestoreRestClient.instance.upsertDocument(
        session: session,
        path: 'organizations/$organizationId/catalogItems/$id',
        data: data,
      );
      return CatalogItem.fromMap(data);
    }

    await _db
        .collection('organizations')
        .doc(organizationId)
        .collection('catalogItems')
        .doc(id)
        .set(data, SetOptions(merge: true));
    return CatalogItem.fromMap(data);
  }

  Future<List<CatalogItem>> list(
    String organizationId, {
    int limit = 50,
    String? category,
  }) async {
    if (_useRest) {
      final session = AuthService.instance.restSession;
      if (session == null) return [];
      final maps = await FirestoreRestClient.instance.listCollection(
        session: session,
        path: 'organizations/$organizationId/catalogItems',
        pageSize: limit,
      );
      var items = maps.map(CatalogItem.fromMap).toList();
      if (category != null) {
        items = items.where((i) => i.category == category).toList();
      }
      items.sort((a, b) => a.name.compareTo(b.name));
      return items;
    }

    Query<Map<String, dynamic>> q = _db
        .collection('organizations')
        .doc(organizationId)
        .collection('catalogItems')
        .orderBy('name');
    if (category != null) {
      q = _db
          .collection('organizations')
          .doc(organizationId)
          .collection('catalogItems')
          .where('category', isEqualTo: category)
          .orderBy('name');
    }
    final snap = await q.limit(limit).get();
    return snap.docs.map((d) => CatalogItem.fromMap(d.data())).toList();
  }

  Future<void> delete(String organizationId, String itemId) async {
    if (_useRest) {
      final session = AuthService.instance.restSession;
      if (session == null) return;
      await FirestoreRestClient.instance.deleteDocument(
        session: session,
        path: 'organizations/$organizationId/catalogItems/$itemId',
      );
      return;
    }
    await _db
        .collection('organizations')
        .doc(organizationId)
        .collection('catalogItems')
        .doc(itemId)
        .delete();
  }
}
