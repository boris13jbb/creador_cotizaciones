import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Monitor de conectividad + comprobación real de alcanzabilidad de Firebase.
class ConnectivityMonitor {
  ConnectivityMonitor._();
  static final ConnectivityMonitor instance = ConnectivityMonitor._();

  final _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  final _controller = StreamController<bool>.broadcast();

  bool _hasNetworkInterface = true;
  bool _firebaseReachable = true;

  Stream<bool> get onChanged => _controller.stream;
  bool get hasNetworkInterface => _hasNetworkInterface;
  bool get firebaseReachable => _firebaseReachable;

  /// True solo si hay interfaz de red y Firebase respondió recientemente.
  bool get isEffectivelyOnline => _hasNetworkInterface && _firebaseReachable;

  Future<void> start() async {
    if (kIsWeb) {
      _hasNetworkInterface = true;
      _firebaseReachable = true;
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

  /// HEAD/GET ligero a Google/Firebase para no confiar solo en Wi‑Fi.
  Future<bool> probeFirebase() async {
    if (!_hasNetworkInterface) {
      _firebaseReachable = false;
      return false;
    }
    try {
      final res = await http
          .get(Uri.parse('https://firestore.googleapis.com/'))
          .timeout(const Duration(seconds: 5));
      // 404/400 también implican red + host alcanzable.
      _firebaseReachable = res.statusCode < 500;
    } catch (_) {
      _firebaseReachable = false;
    }
    _controller.add(isEffectivelyOnline);
    return _firebaseReachable;
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    await _controller.close();
  }
}
