import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'identity_toolkit_client.dart';

/// Persistencia segura de sesión REST (Windows/Linux).
class SecureSessionStore {
  SecureSessionStore._();
  static final SecureSessionStore instance = SecureSessionStore._();

  static const _key = 'cotiapp_rest_session_v1';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> save(AuthSession session) async {
    final payload = jsonEncode({
      'uid': session.uid,
      'email': session.email,
      'idToken': session.idToken,
      'refreshToken': session.refreshToken,
      'displayName': session.displayName,
      'expiresAtEpochMs': session.expiresAt?.millisecondsSinceEpoch,
    });
    await _storage.write(key: _key, value: payload);
  }

  Future<AuthSession?> read() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final uid = map['uid'] as String? ?? '';
      final refresh = map['refreshToken'] as String? ?? '';
      if (uid.isEmpty || refresh.isEmpty) return null;
      DateTime? expiresAt;
      final epoch = map['expiresAtEpochMs'];
      if (epoch is int) {
        expiresAt = DateTime.fromMillisecondsSinceEpoch(epoch, isUtc: true);
      }
      return AuthSession(
        uid: uid,
        email: map['email'] as String? ?? '',
        idToken: map['idToken'] as String? ?? '',
        refreshToken: refresh,
        displayName: map['displayName'] as String?,
        expiresAt: expiresAt,
      );
    } catch (e, st) {
      debugPrint('SecureSessionStore.read: $e\n$st');
      return null;
    }
  }

  Future<void> clear() async {
    await _storage.delete(key: _key);
  }
}
