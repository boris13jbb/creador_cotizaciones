import 'package:cloud_functions/cloud_functions.dart';

/// Cliente de Cloud Functions de plataforma (solo con claim platformAdmin).
class AdminApi {
  AdminApi({FirebaseFunctions? functions})
    : _fn = functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _fn;

  Future<Map<String, dynamic>> _call(
    String name, [
    Map<String, dynamic>? data,
  ]) async {
    final result = await _fn.httpsCallable(name).call(data ?? {});
    final raw = result.data;
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return {'raw': raw};
  }

  Future<Map<String, dynamic>> bootstrap(String secret) =>
      _call('bootstrapPlatformAdmin', {'secret': secret});

  Future<Map<String, dynamic>> lookupUser({String? email, String? uid}) =>
      _call('adminLookupUser', {
        if (email != null && email.isNotEmpty) 'email': email,
        if (uid != null && uid.isNotEmpty) 'uid': uid,
      });

  Future<Map<String, dynamic>> grant({
    required String uid,
    required String plan,
    required String reason,
    String? expiresAt,
  }) => _call('adminGrantEntitlement', {
    'uid': uid,
    'plan': plan,
    'reason': reason,
    'expiresAt': ?expiresAt,
  });

  Future<Map<String, dynamic>> revoke({required String uid, String? grantId}) =>
      _call('adminRevokeGrant', {'uid': uid, 'grantId': ?grantId});

  Future<Map<String, dynamic>> listGrants({int limit = 50}) =>
      _call('adminListGrants', {'limit': limit});

  Future<Map<String, dynamic>> stats() => _call('adminGetPlatformStats');
}
