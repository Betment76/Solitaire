import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solitaire/core/app_table_background.dart';

void main() {
  test('kAppTableBackgroundDecoration задан', () {
    expect(kAppTableBackgroundDecoration.gradient?.colors.length, greaterThan(0));
  });

  testWidgets('themeOnTable с formFields не падает', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Builder(
          builder: (context) {
            final t = themeOnTable(context, formFields: true);
            final id = t.inputDecorationTheme;
            return Scaffold(
              body: Text(
                id.labelStyle!.color.toString(),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
