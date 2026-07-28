import 'package:flutter_test/flutter_test.dart';
import 'package:partivolt/main.dart';

void main() {
  testWidgets('Partivolt smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PartiVoltApp());
    expect(find.text('PARTIVOLT'), findsAny);
  });
}
