import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:solitaire/core/l10n/app_strings.dart';

void main() {
  test('AppStrings RU: известный ключ', () {
    final s = AppStrings(const Locale('ru'));
    expect(s.t('klondike'), 'Косынка');
  });

  test('AppStrings EN: известный ключ', () {
    final s = AppStrings(const Locale('en'));
    expect(s.t('klondike'), 'Klondike');
  });

  test('AppStrings: неизвестный ключ — возврат ключа как строки', () {
    final s = AppStrings(const Locale('ru'));
    expect(s.t('totallyUnknownKeyThatDoesNotExist'), 'totallyUnknownKeyThatDoesNotExist');
  });
}
