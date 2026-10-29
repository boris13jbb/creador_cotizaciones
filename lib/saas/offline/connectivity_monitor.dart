import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Monitor de conectividad + comprobación real de alcanzabilidad de Firebase.
class ConnectivityMonitor {
  ConnectivityMonitor._();
  static final ConnectivityMonitor instance = ConnectivityMonitor._();

  /// Probe nativo (Android/Windows). No usar en Web: CORS bloquea el origen.
  @visibleForTesting
  static final Uri nativeFirebaseProbeUri = Uri.parse(
    'https://firestore.googleapis.com/',
  );

  final _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  final _controller = StreamController<bool>.broadcast();

  bool _hasNetworkInterface = true;
  bool _firebaseReachable = true;

  /// Permite tests de VM simular Web sin compilar para navegador.
  @visibleForTesting
  static bool? isWebOverrideForTests;

  /// Cliente HTTP inyectable (solo el probe nativo lo usa).
  @visibleForTesting
  static http.Client? httpClientForTests;

  bool get _isWeb => isWebOverrideForTests ?? kIsWeb;

  Stream<bool> get onChanged => _controller.stream;
  bool get hasNetworkInterface => _hasNetworkInterface;
  bool get firebaseReachable => _firebaseReachable;

  /// True solo si hay interfaz de red y Firebase se considera alcanzable.
  bool get isEffectivelyOnline => _hasNetworkInterface && _firebaseReachable;

  Future<void> start() async {
    if (_isWeb) {
      await _refreshWebConnectivity();
      _sub ??= _connectivity.onConnectivityChanged.listen((results) {
        _hasNetworkInterface = _anyOnline(results);
        // En Web no hay probe HTTP a Firestore (CORS). La interfaz de red
        // gobierna el banner; fallos reales de Auth/Firestore los reporta el SDK.
        _firebaseReachable = _hasNetworkInterface;
        _controller.add(isEffectivelyOnline);
      });
      return;
    }
    final initial = await _connectivity.checkConnectivity();
    _hasNetworkInterface = _anyOnline(initial);
    await probeFirebase();
    _sub ??= _connectivity.onConnectivityChanged.listen((results) async {
      _hasNetworkInterface = _anyOnline(results);
      if (_hasNetworkInterface) {
        await probeFirebase();
      } else {
        _firebaseReachable = false;
      }
      _controller.add(isEffectivelyOnline);
    });
  }

  bool _anyOnline(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((r) => r != ConnectivityResult.none);
  }

  Future<void> _refreshWebConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _hasNetworkInterface = _anyOnline(results);
    } catch (_) {
      // Si el plugin falla, no forzar offline (evitar falso banner).
      _hasNetworkInterface = true;
    }
    _firebaseReachable = _hasNetworkInterface;
    _controller.add(isEffectivelyOnline);
  }

  /// Comprobación de alcanzabilidad.
  ///
  /// - **Web:** solo `connectivity_plus` / `navigator.onLine`. Nunca GET a
  ///   `firestore.googleapis.com/` (el navegador lo bloquea por CORS y eso
  ///   se interpretaba como «sin conexión»).
  /// - **Android/Windows:** GET ligero al host de Firestore; 4xx implica
  ///   red + host alcanzable.
  Future<bool> probeFirebase() async {
    if (_isWeb) {
      await _refreshWebConnectivity();
      return _firebaseReachable;
    }
    if (!_hasNetworkInterface) {
      _firebaseReachable = false;
      _controller.add(isEffectivelyOnline);
      return false;
    }
    try {
      final client = httpClientForTests;
      final res = client != null
          ? await client
                .get(nativeFirebaseProbeUri)
                .timeout(const Duration(seconds: 5))
          : await http
                .get(nativeFirebaseProbeUri)
                .timeout(const Duration(seconds: 5));
      // 404/400 también implican red + host alcanzable.
      _firebaseReachable = res.statusCode < 500;
    } catch (_) {
      _firebaseReachable = false;
    }
    _controller.add(isEffectivelyOnline);
    return _firebaseReachable;
  }

  @visibleForTesting
  void resetForTests() {
    _hasNetworkInterface = true;
    _firebaseReachable = true;
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    await _controller.close();
  }
}
