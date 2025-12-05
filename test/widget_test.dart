import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// IMPORTANT: change this to match pubspec.yaml `name:`
// If your pubspec has name: sankalp_app then use package:sankalp_app/main.dart
import 'package:sankalp_app/main.dart';

void main() {
  testWidgets('App builds and shows a MaterialApp', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Verifies that the root MaterialApp is built
    expect(find.byType(MaterialApp), findsOneWidget);

    // Optionally advance a bit to allow initial route frame
    await tester.pump(const Duration(milliseconds: 100));
  });
}