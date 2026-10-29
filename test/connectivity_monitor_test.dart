import 'package:creador_cotizaciones/saas/offline/connectivity_monitor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    ConnectivityMonitor.isWebOverrideForTests = null;
    ConnectivityMonitor.httpClientForTests = null;
    ConnectivityMonitor.instance.resetForTests();
  });

  test('en Web no invoca el GET CORS a firestore.googleapis.com/', () async {
    var httpCalls = 0;
    ConnectivityMonitor.isWebOverrideForTests = true;
    ConnectivityMonitor.httpClientForTests = MockClient((request) async {
      httpCalls++;
      return http.Response('should-not-run', 500);
    });

    await ConnectivityMonitor.instance.probeFirebase();

    // Criterio principal: cero llamadas HTTP al probe nativo (evita CORS).
    expect(httpCalls, 0);
    expect(
      ConnectivityMonitor.nativeFirebaseProbeUri.toString(),
      'https://firestore.googleapis.com/',
    );
  });

  test('en nativo sí usa el probe HTTP al host de Firestore', () async {
    var httpCalls = 0;
    Uri? hit;
    ConnectivityMonitor.isWebOverrideForTests = false;
    ConnectivityMonitor.httpClientForTests = MockClient((request) async {
      httpCalls++;
      hit = request.url;
      return http.Response('Not Found', 404);
    });

    final online = await ConnectivityMonitor.instance.probeFirebase();

    expect(httpCalls, 1);
    expect(hit, ConnectivityMonitor.nativeFirebaseProbeUri);
    expect(online, isTrue);
  });

  test('en nativo un fallo de red marca Firebase inalcanzable', () async {
    ConnectivityMonitor.isWebOverrideForTests = false;
    ConnectivityMonitor.httpClientForTests = MockClient((request) async {
      throw Exception('network down');
    });

    final online = await ConnectivityMonitor.instance.probeFirebase();

    expect(online, isFalse);
    expect(ConnectivityMonitor.instance.firebaseReachable, isFalse);
  });
}

bool requestWouldHitNativeProbe(Uri uri) =>
    uri.toString() == 'https://firestore.googleapis.com/';
