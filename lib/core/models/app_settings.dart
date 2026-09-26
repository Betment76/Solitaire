import 'package:flutter/material.dart';

enum DealSpeed { fast, normal, cinematic }

/// Стиль лицевой стороны карты (как рисуем открытую карту).
enum CardFaceStyle { classic, minimal }

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
    this.tableBackground = 'bg_green',
    this.klondikeDrawCount = 1,
    this.spiderSuitCount = 1,
    this.cardScale = 1.0,
    this.showTimer = true,
  });

  final String? languageCode;
  final bool soundOn;
  final bool vibrationOn;
  /// Показывать таймер в игре; при выкл. время не идёт в рекорды.
  final bool showTimer;
  final DealSpeed dealSpeed;
  final ThemeMode themeMode;
  final String cardBack;
  final CardFaceStyle cardFaceStyle;
  /// ID фона стола (bg_green, bg_blue, bg_dark, bg_cosmos, bg_wood, bg_gold).
  final String tableBackground;
  /// Косынка: 1 или 3 карты из колоды за раз.
  final int klondikeDrawCount;
  /// Паук: сколько мастей используется в раздаче (1, 2 или 4).
  final int spiderSuitCount;
  /// Масштаб карт: 0.8 = мелкие, 1.0 = обычные, 1.4 = крупные (для планшетов).
  final double cardScale;

  AppSettings copyWith({
    String? languageCode,
    bool? soundOn,
    bool? vibrationOn,
    DealSpeed? dealSpeed,
    ThemeMode? themeMode,
    String? cardBack,
    CardFaceStyle? cardFaceStyle,
    String? tableBackground,
    int? klondikeDrawCount,
    int? spiderSuitCount,
    double? cardScale,
    bool? showTimer,
  }) {
    return AppSettings(
      languageCode: languageCode ?? this.languageCode,
      soundOn: soundOn ?? this.soundOn,
      vibrationOn: vibrationOn ?? this.vibrationOn,
      showTimer: showTimer ?? this.showTimer,
      dealSpeed: dealSpeed ?? this.dealSpeed,
      themeMode: themeMode ?? this.themeMode,
      cardBack: cardBack ?? this.cardBack,
      cardFaceStyle: cardFaceStyle ?? this.cardFaceStyle,
      tableBackground: tableBackground ?? this.tableBackground,
      klondikeDrawCount: klondikeDrawCount ?? this.klondikeDrawCount,
      spiderSuitCount: spiderSuitCount ?? this.spiderSuitCount,
      cardScale: cardScale ?? this.cardScale,
    );
  }
}