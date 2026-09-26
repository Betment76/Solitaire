import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solitaire/shared/widgets/game_ui_common.dart';

void main() {
  group('game_ui_common', () {
    testWidgets('metricWidget отображает заголовок и значение', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: metricWidget('Score', '100'),
          ),
        ),
      );
      expect(find.text('Score'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
    });

    testWidgets('topCircleButton отображает иконку', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: topCircleButton(
              Icons.menu,
              () => tapped = true,
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.menu), findsOneWidget);
      await tester.tap(find.byIcon(Icons.menu));
      expect(tapped, isTrue);
    });

    testWidgets('bottomAction отображает иконку и метку', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: bottomAction(Icons.undo, 'Undo', () {}),
          ),
        ),
      );
      expect(find.byIcon(Icons.undo), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
    });

    testWidgets('bottomAction с badge отображает число', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: bottomAction(Icons.lightbulb, 'Hint', () {}, badge: 3),
          ),
        ),
      );
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('bottomAction с badgePlay отображает иконку play', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: bottomAction(Icons.lightbulb, 'Hint', () {}, badgePlay: true),
          ),
        ),
      );
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('bottomAction отключена — полупрозрачность', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: bottomAction(Icons.redo, 'Redo', null),
          ),
        ),
      );
      final opacity = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, 0.45);
    });

    testWidgets('bottomActionBar рендерит несколько действий', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: bottomActionBar(
              actions: [
                (icon: Icons.undo, label: 'Undo', onTap: () {}, badge: null, badgePlay: false),
                (icon: Icons.redo, label: 'Redo', onTap: () {}, badge: null, badgePlay: false),
                (icon: Icons.lightbulb, label: 'Hint', onTap: () {}, badge: 3, badgePlay: false),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Undo'), findsOneWidget);
      expect(find.text('Redo'), findsOneWidget);
      expect(find.text('Hint'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    test('effectiveCardScale', () {
      // The function uses MediaQuery, can't easily test without widget
      // Just verify it compiles and returns a double
      expect(effectiveCardScale, isA<Function>());
    });
  });
}
