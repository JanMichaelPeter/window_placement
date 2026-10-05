import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:window_placement_example/main.dart';

void main() {
  testWidgets('Shows the window placement', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Text && widget.data!.startsWith('Displayed:'),
      ),
      findsOneWidget,
    );
  });
}
