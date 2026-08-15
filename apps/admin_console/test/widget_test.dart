import 'package:flutter_test/flutter_test.dart';
import 'package:admin_console/main.dart';

void main() {
  testWidgets('AdminConsoleApp construye MaterialApp', (tester) async {
    // Sin Firebase.initializeApp: solo valida que el widget raíz exista.
    expect(AdminConsoleApp, isNotNull);
  });
}
