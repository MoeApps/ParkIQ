import 'package:flutter_test/flutter_test.dart';
import 'package:parkiq/main.dart';

void main() {
  testWidgets('ParkIQ app launches login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ParkIQApp());
    await tester.pumpAndSettle();

    expect(find.text('PARKIQ'), findsOneWidget);
  });
}
