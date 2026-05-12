import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solitaire/core/models/app_settings.dart';

void main() {
  test('AppSettings по умолчанию', () {
    const s = AppSettings();
    expect(s.soundOn, isTrue);
    expect(s.klondikeDrawCount, 1);
    expect(s.spiderSuitCount, 1);
    expect(s.dealSpeed, DealSpeed.normal);
    expect(s.themeMode, ThemeMode.system);
  });

  test('AppSettings copyWith частично меняет поля', () {
    const s = AppSettings();
    final n = s.copyWith(languageCode: 'en', klondikeDrawCount: 3, soundOn: false);
    expect(n.languageCode, 'en');
    expect(n.klondikeDrawCount, 3);
    expect(n.soundOn, isFalse);
    expect(n.vibrationOn, s.vibrationOn);
    expect(n.spiderSuitCount, s.spiderSuitCount);
  });
}
