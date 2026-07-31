import 'package:flutter_test/flutter_test.dart';
import 'package:creador_cotizaciones/main.dart';

void main() {
  testWidgets('Counter smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CotiApp());

    // Verify that our app starts.
    expect(find.text('CotiApp'), findsOneWidget);
  });
}
