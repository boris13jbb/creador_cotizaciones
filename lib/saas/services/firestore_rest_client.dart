import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import '../../models/cotizacion.dart';
import '../../models/servicio.dart';
import 'identity_toolkit_client.dart';

/// Persistencia Firestore vía REST para cotizaciones (Windows).
class FirestoreRestClient {
  FirestoreRestClient._();
  static final FirestoreRestClient instance = FirestoreRestClient._();

  String get _projectId => IdentityToolkitClient.instance.projectId;

  Uri _doc(String uid, String id) => Uri.parse(
        'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/users/$uid/cotizaciones/$id',
      );

  Uri _col(String uid) => Uri.parse(
        'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/users/$uid/cotizaciones',
      );

  Uri _userDoc(String uid) => Uri.parse(
        'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/users/$uid',
      );

  Future<void> upsertUserProfile({
    required AuthSession session,
    required Map<String, dynamic> profile,
  }) async {
    final res = await http.patch(
      _userDoc(session.uid),
      headers: _headers(session.idToken),
      body: jsonEncode({'fields': _toFields(profile)}),
    );
    _ensureOk(res, 'upsertUserProfile');
  }

  Future<void> upsertCotizacion({
    required AuthSession session,
    required Cotizacion cot,
  }) async {
    final data = cot.toMap();
    data['userId'] = session.uid;
    data['updatedAt'] = DateTime.now().toIso8601String();
    data['servicios'] = cot.servicios.map((s) => s.toMap()).toList();
    final res = await http.patch(
      _doc(session.uid, cot.id),
      headers: _headers(session.idToken),
      body: jsonEncode({'fields': _toFields(data)}),
    );
    _ensureOk(res, 'upsertCotizacion');
  }

  Future<List<Cotizacion>> listCotizaciones(AuthSession session) async {
    final res = await http.get(_col(session.uid), headers: _headers(session.idToken));
    if (res.statusCode == 404) return [];
    _ensureOk(res, 'listCotizaciones');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final docs = (body['documents'] as List<dynamic>?) ?? [];
    final list = docs.map((d) {
      final map = _fromFields(Map<String, dynamic>.from(d['fields'] as Map? ?? {}));
      map.remove('userId');
      final updatedAt = map.remove('updatedAt')?.toString() ?? '';
      return MapEntry(updatedAt, _fromDoc(map));
    }).toList();
    list.sort((a, b) => b.key.compareTo(a.key));
    return list.map((e) => e.value).toList();
  }

  Future<void> deleteCotizacion(AuthSession session, String id) async {
    final res = await http.delete(
      _doc(session.uid, id),
      headers: _headers(session.idToken),
    );
    if (res.statusCode == 404) return;
    _ensureOk(res, 'deleteCotizacion');
  }

  Cotizacion _fromDoc(Map<String, dynamic> data) {
    final serviciosRaw = (data['servicios'] as List<dynamic>?) ?? [];
    final servicios = serviciosRaw.map((e) {
      if (e is Map) {
        return Servicio.fromMap(Map<String, dynamic>.from(e));
      }
      return Servicio(nombre: '', descripcion: '', precio: 0);
    }).toList();
    final map = Map<String, dynamic>.from(data);
    map.remove('servicios');
    return Cotizacion.fromMap(map, servicios);
  }

  Map<String, String> _headers(String idToken) => {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      };

  void _ensureOk(http.Response res, String op) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    debugPrint('Firestore REST [$op] ${res.statusCode}: ${res.body}');
    throw Exception('Error de nube ($op). Código ${res.statusCode}.');
  }

  Map<String, dynamic> _toFields(Map<String, dynamic> data) {
    final out = <String, dynamic>{};
    data.forEach((key, value) {
      out[key] = _toValue(value);
    });
    return out;
  }

  Map<String, dynamic> _toValue(dynamic value) {
    if (value == null) return {'nullValue': null};
    if (value is String) return {'stringValue': value};
    if (value is bool) return {'booleanValue': value};
    if (value is int) return {'integerValue': '$value'};
    if (value is double) return {'doubleValue': value};
    if (value is num) return {'doubleValue': value.toDouble()};
    if (value is List) {
      return {
        'arrayValue': {
          'values': value.map(_toValue).toList(),
        },
      };
    }
    if (value is Map) {
      final fields = <String, dynamic>{};
      value.forEach((k, v) {
        fields['$k'] = _toValue(v);
      });
      return {
        'mapValue': {'fields': fields},
      };
    }
    return {'stringValue': value.toString()};
  }

  Map<String, dynamic> _fromFields(Map<String, dynamic> fields) {
    final out = <String, dynamic>{};
    fields.forEach((key, raw) {
      out[key] = _fromValue(Map<String, dynamic>.from(raw as Map));
    });
    return out;
  }

  dynamic _fromValue(Map<String, dynamic> v) {
    if (v.containsKey('stringValue')) return v['stringValue'];
    if (v.containsKey('integerValue')) return int.tryParse('${v['integerValue']}') ?? 0;
    if (v.containsKey('doubleValue')) return (v['doubleValue'] as num).toDouble();
    if (v.containsKey('booleanValue')) return v['booleanValue'] == true;
    if (v.containsKey('arrayValue')) {
      final values = (v['arrayValue']?['values'] as List<dynamic>?) ?? [];
      return values.map((e) => _fromValue(Map<String, dynamic>.from(e as Map))).toList();
    }
    if (v.containsKey('mapValue')) {
      final nested = Map<String, dynamic>.from(v['mapValue']?['fields'] as Map? ?? {});
      return _fromFields(nested);
    }
    return null;
  }
}
