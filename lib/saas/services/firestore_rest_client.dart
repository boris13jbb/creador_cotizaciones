import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import '../../models/cotizacion.dart';
import '../../models/servicio.dart';
import 'auth_service.dart';
import 'identity_toolkit_client.dart';

/// Persistencia Firestore vía REST para Windows/Linux.
class FirestoreRestClient {
  FirestoreRestClient._();
  static final FirestoreRestClient instance = FirestoreRestClient._();

  String get _projectId => IdentityToolkitClient.instance.projectId;

  Uri _absolute(String docPath) => Uri.parse(
    'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/$docPath',
  );

  Uri _doc(String uid, String id) => _absolute('users/$uid/cotizaciones/$id');

  Uri _col(String uid) => _absolute('users/$uid/cotizaciones');

  Uri _userDoc(String uid) => _absolute('users/$uid');

  Future<Map<String, dynamic>?> getDocument({
    required AuthSession session,
    required String path,
  }) async {
    final res = await _authorized(
      (token) => http.get(_absolute(path), headers: _headers(token)),
      session: session,
      op: 'getDocument:$path',
    );
    if (res.statusCode == 404) return null;
    // Firestore suele responder 403 (no 404) si las rules niegan el read
    // de un documento inexistente o sin membresía.
    if (res.statusCode == 403) return null;
    _ensureOk(res, 'getDocument');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final fields = body['fields'] as Map<String, dynamic>?;
    if (fields == null) return null;
    return _fromFields(fields);
  }

  /// Crea el documento si no existe. No hace pre-read: en orgs/miembros
  /// el GET previo suele fallar con 403 aunque el doc aún no exista.
  Future<void> createDocumentIfAbsent({
    required AuthSession session,
    required String path,
    required Map<String, dynamic> data,
  }) async {
    final parts = path.split('/');
    final docId = parts.last;
    final parent = parts.sublist(0, parts.length - 1).join('/');
    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/$parent?documentId=$docId',
    );
    final res = await _authorized(
      (token) => http.post(
        uri,
        headers: _headers(token),
        body: jsonEncode({'fields': _toFields(_withoutNulls(data))}),
      ),
      session: session,
      op: 'createDocumentIfAbsent',
    );
    // 409 = already exists
    if (res.statusCode == 409) return;
    _ensureOk(res, 'createDocumentIfAbsent');
  }

  Map<String, dynamic> _withoutNulls(Map<String, dynamic> data) {
    final out = <String, dynamic>{};
    data.forEach((key, value) {
      if (value != null) out[key] = value;
    });
    return out;
  }

  /// Solo campos de perfil editables (nunca plan/suscripción).
  Future<void> upsertEditableProfile({
    required AuthSession session,
    required Map<String, dynamic> profile,
  }) async {
    final allowed = <String, dynamic>{
      'uid': profile['uid'],
      'email': profile['email'],
      'displayName': profile['displayName'],
      'createdAt': profile['createdAt'],
      'updatedAt': profile['updatedAt'],
    };
    if (profile['defaultOrganizationId'] != null) {
      allowed['defaultOrganizationId'] = profile['defaultOrganizationId'];
    }
    final maskQuery = allowed.keys
        .map((k) => 'updateMask.fieldPaths=${Uri.encodeQueryComponent(k)}')
        .join('&');
    final patchUri = Uri.parse('${_userDoc(session.uid)}?$maskQuery');
    final res = await _authorized(
      (token) => http.patch(
        patchUri,
        headers: _headers(token),
        body: jsonEncode({'fields': _toFields(allowed)}),
      ),
      session: session,
      op: 'upsertEditableProfile',
    );
    _ensureOk(res, 'upsertEditableProfile');
  }

  Future<List<Map<String, dynamic>>> listCollection({
    required AuthSession session,
    required String path,
    int pageSize = 50,
    String? pageToken,
  }) async {
    final qp = <String, String>{'pageSize': '$pageSize'};
    if (pageToken != null && pageToken.isNotEmpty) {
      qp['pageToken'] = pageToken;
    }
    final uri = _absolute(path).replace(queryParameters: qp);
    final res = await _authorized(
      (token) => http.get(uri, headers: _headers(token)),
      session: session,
      op: 'listCollection:$path',
    );
    if (res.statusCode == 404) return [];
    _ensureOk(res, 'listCollection');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final docs = (body['documents'] as List<dynamic>?) ?? [];
    return docs.map((d) {
      final fields = Map<String, dynamic>.from(d['fields'] as Map? ?? {});
      return _fromFields(fields);
    }).toList();
  }

  Future<void> upsertDocument({
    required AuthSession session,
    required String path,
    required Map<String, dynamic> data,
  }) async {
    final res = await _authorized(
      (token) => http.patch(
        _absolute(path),
        headers: _headers(token),
        body: jsonEncode({'fields': _toFields(data)}),
      ),
      session: session,
      op: 'upsertDocument:$path',
    );
    _ensureOk(res, 'upsertDocument');
  }

  Future<void> deleteDocument({
    required AuthSession session,
    required String path,
  }) async {
    final res = await _authorized(
      (token) => http.delete(_absolute(path), headers: _headers(token)),
      session: session,
      op: 'deleteDocument:$path',
    );
    if (res.statusCode == 404) return;
    _ensureOk(res, 'deleteDocument');
  }

  @Deprecated('Usar upsertEditableProfile')
  Future<void> upsertUserProfile({
    required AuthSession session,
    required Map<String, dynamic> profile,
  }) => upsertEditableProfile(session: session, profile: profile);

  Future<void> upsertCotizacion({
    required AuthSession session,
    required Cotizacion cot,
  }) async {
    final data = cot.toMap();
    data['userId'] = session.uid;
    data['updatedAt'] = DateTime.now().toIso8601String();
    data['servicios'] = cot.servicios.map((s) => s.toMap()).toList();
    final res = await _authorized(
      (token) => http.patch(
        _doc(session.uid, cot.id),
        headers: _headers(token),
        body: jsonEncode({'fields': _toFields(data)}),
      ),
      session: session,
      op: 'upsertCotizacion',
    );
    _ensureOk(res, 'upsertCotizacion');
  }

  Future<List<Cotizacion>> listCotizaciones(AuthSession session) async {
    final res = await _authorized(
      (token) => http.get(_col(session.uid), headers: _headers(token)),
      session: session,
      op: 'listCotizaciones',
    );
    if (res.statusCode == 404) return [];
    _ensureOk(res, 'listCotizaciones');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final docs = (body['documents'] as List<dynamic>?) ?? [];
    final list = docs.map((d) {
      final map = _fromFields(
        Map<String, dynamic>.from(d['fields'] as Map? ?? {}),
      );
      map.remove('userId');
      final updatedAt = map.remove('updatedAt')?.toString() ?? '';
      return MapEntry(updatedAt, _fromDoc(map));
    }).toList();
    list.sort((a, b) => b.key.compareTo(a.key));
    return list.map((e) => e.value).toList();
  }

  Future<void> deleteCotizacion(AuthSession session, String id) async {
    final res = await _authorized(
      (token) => http.delete(_doc(session.uid, id), headers: _headers(token)),
      session: session,
      op: 'deleteCotizacion',
    );
    if (res.statusCode == 404) return;
    _ensureOk(res, 'deleteCotizacion');
  }

  Future<void> deleteAllCotizaciones(AuthSession session) async {
    final list = await listCotizaciones(session);
    for (final cot in list) {
      await deleteCotizacion(session, cot.id);
    }
  }

  /// Ejecuta [request] con token fresco; reintenta una vez tras 401.
  Future<http.Response> _authorized(
    Future<http.Response> Function(String idToken) request, {
    required AuthSession session,
    required String op,
  }) async {
    var current = session;
    try {
      current = await AuthService.instance.ensureValidRestSession();
    } catch (_) {
      current = session;
    }

    var res = await request(current.idToken);
    if (res.statusCode != 401) return res;

    debugPrint('Firestore REST [$op] 401 → renovando token y reintentando');
    try {
      current = await AuthService.instance.ensureValidRestSession();
    } catch (e) {
      rethrow;
    }
    res = await request(current.idToken);
    if (res.statusCode == 401) {
      await AuthService.instance.signOut();
      throw Exception('Sesión expirada. Vuelve a iniciar sesión.');
    }
    return res;
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
    if (res.statusCode == 403) {
      throw Exception(
        'Sin permisos en Firestore ($op). Verifica que las reglas '
        'estén desplegadas en el proyecto y que la sesión sea válida.',
      );
    }
    if (res.statusCode == 401) {
      throw Exception('Sesión expirada. Vuelve a iniciar sesión.');
    }
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
        'arrayValue': {'values': value.map(_toValue).toList()},
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
    if (v.containsKey('integerValue')) {
      return int.tryParse('${v['integerValue']}') ?? 0;
    }
    if (v.containsKey('doubleValue')) {
      return (v['doubleValue'] as num).toDouble();
    }
    if (v.containsKey('booleanValue')) return v['booleanValue'] == true;
    if (v.containsKey('arrayValue')) {
      final values = (v['arrayValue']?['values'] as List<dynamic>?) ?? [];
      return values
          .map((e) => _fromValue(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    if (v.containsKey('mapValue')) {
      final nested = Map<String, dynamic>.from(
        v['mapValue']?['fields'] as Map? ?? {},
      );
      return _fromFields(nested);
    }
    return null;
  }
}
