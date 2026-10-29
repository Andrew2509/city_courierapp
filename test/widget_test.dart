// Basic app boot test.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:city_courierapp/main.dart';

void main() {
  testWidgets('App smoke test - boots without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
