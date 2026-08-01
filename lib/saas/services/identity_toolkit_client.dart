import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

/// Sesión obtenida vía Identity Toolkit (REST).
class AuthSession {
  final String uid;
  final String email;
  final String idToken;
  final String refreshToken;
  final String? displayName;
  final DateTime? expiresAt;

  const AuthSession({
    required this.uid,
    required this.email,
    required this.idToken,
    required this.refreshToken,
    this.displayName,
    this.expiresAt,
  });

  bool get isExpiredOrNearExpiry {
    if (expiresAt == null) return true;
    return DateTime.now().toUtc().isAfter(
      expiresAt!.subtract(const Duration(minutes: 2)),
    );
  }

  AuthSession copyWith({
    String? uid,
    String? email,
    String? idToken,
    String? refreshToken,
    String? displayName,
    DateTime? expiresAt,
  }) {
    return AuthSession(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      idToken: idToken ?? this.idToken,
      refreshToken: refreshToken ?? this.refreshToken,
      displayName: displayName ?? this.displayName,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}

/// Cliente REST de Firebase Auth (Windows/Linux: FlutterFire no es producción en desktop).
class IdentityToolkitClient {
  IdentityToolkitClient._();
  static final IdentityToolkitClient instance = IdentityToolkitClient._();

  String get _apiKey => Firebase.app().options.apiKey;
  String get _projectId => Firebase.app().options.projectId;

  Future<AuthSession> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final body = <String, dynamic>{
      'email': email.trim(),
      'password': password,
      'returnSecureToken': true,
    };
    if (displayName != null && displayName.trim().isNotEmpty) {
      body['displayName'] = displayName.trim();
    }
    final data = await _post('accounts:signUp', body);
    return _sessionFrom(data, fallbackEmail: email.trim());
  }

  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    final data = await _post('accounts:signInWithPassword', {
      'email': email.trim(),
      'password': password,
      'returnSecureToken': true,
    });
    return _sessionFrom(data, fallbackEmail: email.trim());
  }

  Future<void> sendPasswordReset(String email) async {
    await _post('accounts:sendOobCode', {
      'requestType': 'PASSWORD_RESET',
      'email': email.trim(),
    });
  }

  Future<void> sendEmailVerification(String idToken) async {
    await _post('accounts:sendOobCode', {
      'requestType': 'VERIFY_EMAIL',
      'idToken': idToken,
    });
  }

  Future<AuthSession> lookupAccount(String idToken) async {
    final data = await _post('accounts:lookup', {'idToken': idToken});
    final users = (data['users'] as List?) ?? [];
    if (users.isEmpty) {
      throw Exception('Cuenta no encontrada o token inválido.');
    }
    final user = Map<String, dynamic>.from(users.first as Map);
    final disabled = user['disabled'] == true;
    if (disabled) {
      throw Exception('Esta cuenta está deshabilitada.');
    }
    return AuthSession(
      uid: user['localId'] as String? ?? '',
      email: user['email'] as String? ?? '',
      idToken: idToken,
      refreshToken: '',
      displayName: user['displayName'] as String?,
    );
  }

  Future<bool> isEmailVerified(String idToken) async {
    final data = await _post('accounts:lookup', {'idToken': idToken});
    final users = (data['users'] as List?) ?? [];
    if (users.isEmpty) return false;
    final user = Map<String, dynamic>.from(users.first as Map);
    return user['emailVerified'] == true;
  }

  Future<AuthSession> refresh(String refreshToken) async {
    final uri = Uri.parse(
      'https://securetoken.googleapis.com/v1/token?key=$_apiKey',
    );
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: 'grant_type=refresh_token&refresh_token=$refreshToken',
    );
    final data = jsonDecode(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final error = data is Map ? data['error'] : null;
      final message =
          (error is Map ? error['message'] : null) ?? 'REFRESH_FAILED';
      throw Exception(_mapRestError(message.toString()));
    }
    final map = Map<String, dynamic>.from(data as Map);
    final expiresIn = int.tryParse('${map['expires_in'] ?? ''}') ?? 3600;
    return AuthSession(
      uid: map['user_id'] as String? ?? '',
      email: '',
      idToken: map['id_token'] as String? ?? '',
      refreshToken: map['refresh_token'] as String? ?? refreshToken,
      expiresAt: DateTime.now().toUtc().add(Duration(seconds: expiresIn)),
    );
  }

  AuthSession _sessionFrom(
    Map<String, dynamic> data, {
    required String fallbackEmail,
  }) {
    final expiresIn = int.tryParse('${data['expiresIn'] ?? ''}') ?? 3600;
    return AuthSession(
      uid: data['localId'] as String? ?? '',
      email: data['email'] as String? ?? fallbackEmail,
      idToken: data['idToken'] as String? ?? '',
      refreshToken: data['refreshToken'] as String? ?? '',
      displayName: data['displayName'] as String?,
      expiresAt: DateTime.now().toUtc().add(Duration(seconds: expiresIn)),
    );
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse(
      'https://identitytoolkit.googleapis.com/v1/$path?key=$_apiKey',
    );
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    final decoded = jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return Map<String, dynamic>.from(decoded as Map);
    }
    final error = (decoded is Map ? decoded['error'] : null) as Map?;
    final message = (error?['message'] as String?) ?? 'ERROR_DESCONOCIDO';
    debugPrint('IdentityToolkit [$path]: $message');
    throw Exception(_mapRestError(message));
  }

  String get projectId => _projectId;

  String _mapRestError(String message) {
    if (message.startsWith('WEAK_PASSWORD')) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }
    switch (message) {
      case 'EMAIL_EXISTS':
        return 'Ya existe una cuenta con ese correo.';
      case 'INVALID_EMAIL':
        return 'El correo no es válido.';
      case 'EMAIL_NOT_FOUND':
        return 'No existe una cuenta con ese correo.';
      case 'INVALID_PASSWORD':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Correo o contraseña incorrectos.';
      case 'USER_DISABLED':
        return 'Esta cuenta está deshabilitada.';
      case 'TOO_MANY_ATTEMPTS_TRY_LATER':
        return 'Demasiados intentos. Espera un momento.';
      case 'OPERATION_NOT_ALLOWED':
        return 'Activa Email/Password en Firebase Authentication.';
      case 'API_KEY_INVALID':
        return 'API key de Firebase inválida.';
      case 'TOKEN_EXPIRED':
      case 'INVALID_ID_TOKEN':
      case 'INVALID_REFRESH_TOKEN':
        return 'Sesión expirada. Vuelve a iniciar sesión.';
      default:
        return 'No se pudo completar la autenticación ($message).';
    }
  }
}
