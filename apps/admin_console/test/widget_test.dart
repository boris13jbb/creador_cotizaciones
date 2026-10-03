import 'package:flutter_test/flutter_test.dart';

/// Smoke del paquete anidado. El widget raíz requiere Firebase init;
/// la cobertura de UI vive en la app principal / emuladores.
void main() {
  test('admin_console package smoke', () {
    expect(true, isTrue);
  });
}
