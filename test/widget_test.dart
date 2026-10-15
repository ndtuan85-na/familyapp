import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Kiểm tra widget cơ bản', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('Hải sản gia đình'),
        ),
      ),
    );

    expect(
      find.text('Hải sản gia đình'),
      findsOneWidget,
    );
  });
}