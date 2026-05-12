import 'package:flutter/material.dart';

enum DealSpeed { fast, normal, cinematic }

/// Стиль лицевой стороны карты (как рисуем открытую карту).
enum CardFaceStyle { classic, minimal }

/// Стиль фона стола (градиент/цвет под сукно).
enum TableBackgroundStyle { green, blue, dark }

/// Настройки приложения, которые сохраняются локально.
class AppSettings {
  const AppSettings({
    this.languageCode,
    this.soundOn = true,
    this.vibrationOn = true,
    this.dealSpeed = DealSpeed.normal,
    this.themeMode = ThemeMode.system,
    this.cardBack = 'blue',
    this.cardFaceStyle = CardFaceStyle.classic,
    this.tableBackgroundStyle = TableBackgroundStyle.green,
    this.klondikeDrawCount = 1,
    this.spiderSuitCount = 1,
  });

  final String? languageCode;
  final bool soundOn;
  final bool vibrationOn;
  final DealSpeed dealSpeed;
  final ThemeMode themeMode;
  final String cardBack;
  final CardFaceStyle cardFaceStyle;
  final TableBackgroundStyle tableBackgroundStyle;
  /// Косынка: 1 или 3 карты из колоды за раз.
  final int klondikeDrawCount;
  /// Паук: сколько мастей используется в раздаче (1, 2 или 4).
  final int spiderSuitCount;

  AppSettings copyWith({
    String? languageCode,
    bool? soundOn,
    bool? vibrationOn,
    DealSpeed? dealSpeed,
    ThemeMode? themeMode,
    String? cardBack,
    CardFaceStyle? cardFaceStyle,
    TableBackgroundStyle? tableBackgroundStyle,
    int? klondikeDrawCount,
    int? spiderSuitCount,
  }) {
    return AppSettings(
      languageCode: languageCode ?? this.languageCode,
      soundOn: soundOn ?? this.soundOn,
      vibrationOn: vibrationOn ?? this.vibrationOn,
      dealSpeed: dealSpeed ?? this.dealSpeed,
      themeMode: themeMode ?? this.themeMode,
      cardBack: cardBack ?? this.cardBack,
      cardFaceStyle: cardFaceStyle ?? this.cardFaceStyle,
      tableBackgroundStyle: tableBackgroundStyle ?? this.tableBackgroundStyle,
      klondikeDrawCount: klondikeDrawCount ?? this.klondikeDrawCount,
      spiderSuitCount: spiderSuitCount ?? this.spiderSuitCount,
    );
  }
}
