import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solitaire/core/app.dart';
import 'package:solitaire/core/l10n/app_strings.dart';

/// Smoke на устройстве: меню → косынка → ход → выход → диалог «продолжить».
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('косынка: сохранение после выхода в меню', (tester) async {
    // Чистый сейв косынки, чтобы сценарий был предсказуемым.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('game_state_klondike');

    await tester.pumpWidget(const ProviderScope(child: SolitaireApp()));
    await tester.pumpAndSettle(const Duration(seconds: 15));

    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    final klondikeTitle = AppStrings.of(locale).t('klondike');
    expect(find.text(klondikeTitle), findsOneWidget);

    await tester.tap(find.text(klondikeTitle));
    await tester.pumpAndSettle(const Duration(seconds: 15));

    // Сдача из колоды — пишет сейв на диск.
    await tester.tap(find.byKey(const Key('klondike_draw_stock')));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    // Дождаться асинхронного _persist после сдачи.
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle(const Duration(seconds: 10));

    expect(find.text(klondikeTitle), findsOneWidget);

    await tester.tap(find.text(klondikeTitle));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    final continueTitle = AppStrings.of(locale).t('continueGameTitle');
    expect(find.text(continueTitle), findsOneWidget);
  });
}
