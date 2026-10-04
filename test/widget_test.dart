import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:road_rescue/main.dart';

void main() {
  testWidgets('shows the basic RoadRescue app and responds to a tap', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const RoadRescueApp());

    expect(find.text('Welcome to RoadRescue'), findsOneWidget);
    expect(find.text('Button taps: 0'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('increment')));
    await tester.pump();

    expect(find.text('Button taps: 1'), findsOneWidget);
  });
}