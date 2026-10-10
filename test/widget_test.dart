import 'package:flutter_test/flutter_test.dart';
import 'package:road_rescue/main.dart';

void main() {
  testWidgets('shows the RoadRescue onboarding experience', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const RoadRescueApp());

    expect(find.text('Roadside Help,'), findsOneWidget);
    expect(find.text('Anytime'), findsOneWidget);
  });
}
