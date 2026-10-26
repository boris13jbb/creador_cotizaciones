import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../config/saas_platform.dart';
import 'identity_toolkit_client.dart';
import 'secure_session_store.dart';

/// Autenticación SaaS.
/// En Windows/Linux: Identity Toolkit REST (FlutterFire desktop no es producción).
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  FirebaseAuth? _auth;
  AuthSession? _restSession;
  final _restAuthController = StreamController<User?>.broadcast();

  AuthSession? get restSession => _restSession;

  FirebaseAuth get _native {
    _auth ??= FirebaseAuth.instance;
    return _auth!;
  }

  User? get currentUser {
    if (saasUseRestBackend) return null;
    try {
      return _native.currentUser;
    } catch (e) {
      debugPrint('FirebaseAuth.currentUser no disponible: $e');
      return null;
    }
  }

  String? get activeUid => currentUser?.uid ?? _restSession?.uid;

  String? get activeEmail => currentUser?.email ?? _restSession?.email;

  bool get isAuthenticated => activeUid != null && activeUid!.isNotEmpty;

  bool get isEmailVerified {
    if (saasUseRestBackend) {
      // REST: el flag se actualiza vía lookup en AuthController.
      return _restEmailVerified;
    }
    return currentUser?.emailVerified ?? false;
  }

  bool _restEmailVerified = false;

  /// En REST emitimos `null` (la sesión va por [restSession] + AuthController).
  Stream<User?> get authStateChanges {
    if (saasUseRestBackend) {
      return _restAuthController.stream;
    }
    return _native.authStateChanges();
  }

  Future<void> restoreRestSession() async {
    if (!saasUseRestBackend) return;
    final stored = await SecureSessionStore.instance.read();
    if (stored == null) return;
    try {
      final session = stored.isExpiredOrNearExpiry
          ? await _refreshOrThrow(stored)
          : stored;
      _restSession = session;
      await SecureSessionStore.instance.save(session);
      await _refreshRestAccountFlags(session);
      _restAuthController.add(null);
    } catch (e, st) {
      debugPrint('restoreRestSession falló: $e\n$st');
      await SecureSessionStore.instance.clear();
      _restSession = null;
    }
  }

  Future<AuthSession> ensureValidRestSession() async {
    var session = _restSession;
    if (session == null) {
      throw Exception('Sesión no disponible. Inicia sesión de nuevo.');
    }
    if (!session.isExpiredOrNearExpiry && session.idToken.isNotEmpty) {
      return session;
    }
    session = await _refreshOrThrow(session);
    _restSession = session;
    await SecureSessionStore.instance.save(session);
    return session;
  }

  /// True si hay usuario nativo o sesión REST usable para callables.
  bool get hasCallableAuthSession {
    if (saasUseRestBackend) {
      final s = _restSession;
      return s != null && s.uid.isNotEmpty && s.idToken.isNotEmpty;
    }
    final u = currentUser;
    return u != null && u.uid.isNotEmpty;
  }

  /// Garantiza un ID token usable antes de invocar Cloud Functions.
  ///
  /// En Android/iOS/Web el SDK callable adjunta el token de [currentUser];
  /// si está ausente o no se puede renovar, la Function responde
  /// `unauthenticated`. No registra el token.
  ///
  /// [forceRefresh]: fuerza renovación (útil tras cold start / sync offline).
  Future<void> ensureCallableAuth({bool forceRefresh = true}) async {
    if (saasUseRestBackend) {
      await ensureValidRestSession();
      return;
    }
    final user = currentUser;
    if (user == null || user.uid.isEmpty) {
      throw CallableAuthException(
        code: 'unauthenticated',
        message: 'Debes iniciar sesión para sincronizar.',
      );
    }
    try {
      final token = await user.getIdToken(forceRefresh);
      if (token == null || token.isEmpty) {
        throw CallableAuthException(
          code: 'unauthenticated',
          message: 'No se pudo renovar la sesión. Vuelve a iniciar sesión.',
        );
      }
    } on CallableAuthException {
      rethrow;
    } on FirebaseAuthException catch (e) {
      debugPrint('ensureCallableAuth Auth[${e.code}]: token no disponible');
      throw CallableAuthException(
        code: e.code == 'network-request-failed'
            ? 'unavailable'
            : 'unauthenticated',
        message: e.code == 'network-request-failed'
            ? 'Sin conexión para renovar la sesión.'
            : 'Sesión inválida. Vuelve a iniciar sesión.',
        cause: e,
      );
    } catch (e) {
      debugPrint('ensureCallableAuth falló (sin token en log)');
      throw CallableAuthException(
        code: 'unauthenticated',
        message: 'No se pudo preparar la sesión para Cloud Functions.',
        cause: e,
      );
    }
  }

  Future<AuthSession> _refreshOrThrow(AuthSession session) async {
    try {
      final refreshed = await IdentityToolkitClient.instance.refresh(
        session.refreshToken,
      );
      return session.copyWith(
        uid: refreshed.uid.isNotEmpty ? refreshed.uid : session.uid,
        idToken: refreshed.idToken,
        refreshToken: refreshed.refreshToken,
        expiresAt: refreshed.expiresAt,
        email: session.email,
        displayName: session.displayName,
      );
    } catch (e) {
      await signOut();
      throw Exception('Sesión expirada. Vuelve a iniciar sesión.');
    }
  }

  Future<void> _persistRest(AuthSession session) async {
    _restSession = session;
    await SecureSessionStore.instance.save(session);
    await _refreshRestAccountFlags(session);
  }

  Future<void> _refreshRestAccountFlags(AuthSession session) async {
    try {
      final data = await IdentityToolkitClient.instance.lookupAccount(
        session.idToken,
      );
      _restEmailVerified = await IdentityToolkitClient.instance.isEmailVerified(
        session.idToken,
      );
      if (data.email.isNotEmpty) {
        _restSession = session.copyWith(
          email: data.email,
          displayName: data.displayName ?? session.displayName,
        );
      }
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('deshabilitada')) rethrow;
      debugPrint('lookupAccount: $e');
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    if (saasUseRestBackend) {
      final session = await IdentityToolkitClient.instance.signIn(
        email: email,
        password: password,
      );
      await _persistRest(session);
      _restAuthController.add(null);
      return;
    }
    try {
      await _native.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      _restSession = null;
      await SecureSessionStore.instance.clear();
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapNative(e));
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    if (saasUseRestBackend) {
      final session = await IdentityToolkitClient.instance.signUp(
        email: email,
        password: password,
        displayName: displayName,
      );
      await _persistRest(session);
      try {
        await IdentityToolkitClient.instance.sendEmailVerification(
          session.idToken,
        );
      } catch (e) {
        debugPrint('sendEmailVerification REST: $e');
      }
      _restAuthController.add(null);
      return;
    }
    try {
      final cred = await _native.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (displayName != null && displayName.trim().isNotEmpty) {
        await cred.user?.updateDisplayName(displayName.trim());
      }
      try {
        await cred.user?.sendEmailVerification();
      } catch (e) {
        debugPrint('sendEmailVerification: $e');
      }
      _restSession = null;
      await SecureSessionStore.instance.clear();
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapNative(e));
    }
  }

  Future<void> sendEmailVerification() async {
    if (saasUseRestBackend) {
      final session = await ensureValidRestSession();
      await IdentityToolkitClient.instance.sendEmailVerification(
        session.idToken,
      );
      return;
    }
    final user = currentUser;
    if (user == null) throw Exception('Debes iniciar sesión.');
    await user.sendEmailVerification();
  }

  Future<void> reloadUser() async {
    await reloadAndReadEmailStatus();
  }

  /// Recarga el usuario Auth y lee `emailVerified` fresco.
  ///
  /// Tras verificar el correo en el navegador, el SDK local no se actualiza
  /// solo: hace falta `reload()` + volver a leer `currentUser`.
  Future<AuthEmailStatus> reloadAndReadEmailStatus() async {
    if (saasUseRestBackend) {
      try {
        final session = await ensureValidRestSession();
        await _refreshRestAccountFlags(session);
        return AuthEmailStatus(
          hasSession: true,
          email: session.email,
          emailVerified: _restEmailVerified,
          uidPrefix: _uidPrefix(session.uid),
        );
      } catch (e) {
        final network =
            e.toString().toLowerCase().contains('network') ||
            e.toString().contains('Sin conexión');
        return AuthEmailStatus(
          hasSession: _restSession != null,
          email: _restSession?.email ?? '',
          emailVerified: _restEmailVerified,
          uidPrefix: _uidPrefix(_restSession?.uid),
          errorCode: network ? 'unavailable' : 'failed-precondition',
          errorMessage: e.toString().replaceFirst('Exception: ', ''),
        );
      }
    }

    final before = currentUser;
    if (before == null) {
      return const AuthEmailStatus(
        hasSession: false,
        email: '',
        emailVerified: false,
        errorCode: 'unauthenticated',
        errorMessage: 'No hay sesión activa para actualizar el correo.',
      );
    }

    try {
      await before.reload();
      // Tras reload, la instancia anterior puede estar obsoleta.
      final fresh = currentUser;
      if (fresh == null) {
        return const AuthEmailStatus(
          hasSession: false,
          email: '',
          emailVerified: false,
          errorCode: 'unauthenticated',
          errorMessage: 'La sesión ya no está disponible.',
        );
      }
      // Renueva el ID token para que claim/estado queden alineados en callables.
      await fresh.getIdToken(true);
      return AuthEmailStatus(
        hasSession: true,
        email: fresh.email ?? '',
        emailVerified: fresh.emailVerified,
        uidPrefix: _uidPrefix(fresh.uid),
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('reloadAndReadEmailStatus Auth[${e.code}]');
      return AuthEmailStatus(
        hasSession: currentUser != null,
        email: currentUser?.email ?? before.email ?? '',
        emailVerified: currentUser?.emailVerified ?? before.emailVerified,
        uidPrefix: _uidPrefix(currentUser?.uid ?? before.uid),
        errorCode: e.code == 'network-request-failed' ? 'unavailable' : e.code,
        errorMessage: _mapNative(e),
      );
    } catch (e) {
      debugPrint('reloadAndReadEmailStatus: $e');
      return AuthEmailStatus(
        hasSession: currentUser != null,
        email: currentUser?.email ?? before.email ?? '',
        emailVerified: currentUser?.emailVerified ?? false,
        uidPrefix: _uidPrefix(currentUser?.uid ?? before.uid),
        errorCode: 'internal',
        errorMessage: 'No se pudo actualizar el estado del correo.',
      );
    }
  }

  /// Cambios de perfil/claims (incluye emailVerified tras reload).
  Stream<User?> get userChanges {
    if (saasUseRestBackend) {
      return _restAuthController.stream;
    }
    return _native.userChanges();
  }

  static String? _uidPrefix(String? uid) {
    if (uid == null || uid.isEmpty) return null;
    return uid.length <= 6 ? uid : uid.substring(0, 6);
  }

  Future<void> signOut() async {
    _restSession = null;
    _restEmailVerified = false;
    await SecureSessionStore.instance.clear();
    if (saasUseRestBackend) {
      _restAuthController.add(null);
      return;
    }
    try {
      await _native.signOut();
    } catch (e) {
      debugPrint('signOut nativo: $e');
    }
  }

  Future<void> resetPassword(String email) async {
    if (saasUseRestBackend) {
      await IdentityToolkitClient.instance.sendPasswordReset(email);
      return;
    }
    try {
      await _native.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapNative(e));
    }
  }

  /// Elimina la cuenta Auth (nativo). En REST requiere Cloud Function.
  Future<void> deleteNativeAccount() async {
    if (saasUseRestBackend) {
      throw Exception(
        'En escritorio la eliminación de cuenta requiere Cloud Functions desplegadas.',
      );
    }
    final user = currentUser;
    if (user == null) throw Exception('Debes iniciar sesión.');
    await user.delete();
  }

  String _mapNative(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'El correo no es válido.';
      case 'user-disabled':
        return 'Esta cuenta está deshabilitada.';
      case 'user-not-found':
        return 'No existe una cuenta con ese correo.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Correo o contraseña incorrectos.';
      case 'email-already-in-use':
        return 'Ya existe una cuenta con ese correo.';
      case 'weak-password':
        return 'La contraseña debe tener al menos 6 caracteres.';
      case 'too-many-requests':
        return 'Demasiados intentos. Espera un momento.';
      case 'network-request-failed':
        return 'Sin conexión a internet.';
      case 'operation-not-allowed':
        return 'Activa Email/Password en Firebase Authentication.';
      case 'requires-recent-login':
        return 'Por seguridad, vuelve a iniciar sesión e inténtalo de nuevo.';
      case 'internal-error':
      case 'unknown':
      case 'unknown-error':
        return 'Error interno de Auth. Prueba de nuevo.';
      default:
        return e.message ?? 'Error de autenticación (${e.code}).';
    }
  }
}

/// Estado de verificación de correo tras un reload (sin tokens).
class AuthEmailStatus {
  const AuthEmailStatus({
    required this.hasSession,
    required this.email,
    required this.emailVerified,
    this.uidPrefix,
    this.errorCode,
    this.errorMessage,
  });

  final bool hasSession;
  final String email;
  final bool emailVerified;
  final String? uidPrefix;
  final String? errorCode;
  final String? errorMessage;

  bool get ok => errorCode == null && hasSession;

  /// Compara correos de forma segura (case-insensitive).
  static bool emailsMatch(String? a, String? b) {
    final x = (a ?? '').trim().toLowerCase();
    final y = (b ?? '').trim().toLowerCase();
    if (x.isEmpty || y.isEmpty) return true;
    return x == y;
  }
}

/// Fallo al preparar Auth para callables (código estable para sync/UI).
class CallableAuthException implements Exception {
  CallableAuthException({
    required this.code,
    required this.message,
    this.cause,
  });

  final String code;
  final String message;
  final Object? cause;

  bool get isUnauthenticated =>
      code == 'unauthenticated' || code == 'UNAUTHENTICATED';

  @override
  String toString() => 'CallableAuthException($code): $message';
}
