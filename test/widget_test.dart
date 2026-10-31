import 'package:flutter_test/flutter_test.dart';
import 'package:building_app/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const BuildingApp());
    expect(find.byType(BuildingApp), findsOneWidget);
  });
}
