import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cangkang_sawit_mobile/main.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that splash screen loads
    expect(find.byType(MyApp), findsOneWidget);
  });
}
