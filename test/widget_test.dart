import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Material smoke', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Text('MamanaPlus')),
      ),
    );
    expect(find.text('MamanaPlus'), findsOneWidget);
  });
}
