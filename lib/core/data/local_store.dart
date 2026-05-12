import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/app_stats.dart';

/// Репозиторий локального хранения настроек, статистики и сейва партии.
class LocalStore {
  static const _kSettings = 'settings';
  static const _kStats = 'stats';
  static const _kGameKlondike = 'game_state_klondike';
  static const _kGameSpider = 'game_state_spider';
  static const _kGameFreecell = 'game_state_freecell';
  static const _kDailyKlondikeMoves = 'daily_klondike_best_moves';

  Future<AppSettings> loadSettings() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kSettings);
    if (raw == null) return const AppSettings();
    final m = jsonDecode(raw) as Map<String, dynamic>;
    final cinematicLegacy = m['cinematicDealOn'] as bool?;
    final speedRaw = m['dealSpeed'] as String?;
    final dealSpeed = speedRaw != null
        ? DealSpeed.values.firstWhere(
            (v) => v.name == speedRaw,
            orElse: () => DealSpeed.normal,
          )
        : (cinematicLegacy == true ? DealSpeed.cinematic : DealSpeed.normal);
    final rawDraw = m['klondikeDrawCount'] as int? ?? 1;
    final rawSpiderSuitCount = m['spiderSuitCount'] as int? ?? 1;
    final spiderSuitCount = (rawSpiderSuitCount == 2 || rawSpiderSuitCount == 4) ? rawSpiderSuitCount : 1;
    final faceRaw = m['cardFaceStyle'] as String?;
    final tableRaw = m['tableBackgroundStyle'] as String?;
    return AppSettings(
      languageCode: m['languageCode'] as String?,
      soundOn: m['soundOn'] as bool? ?? true,
      vibrationOn: m['vibrationOn'] as bool? ?? true,
      dealSpeed: dealSpeed,
      themeMode: ThemeMode.values[(m['themeMode'] as int? ?? 0).clamp(0, 2)],
      cardBack: m['cardBack'] as String? ?? 'blue',
      cardFaceStyle: faceRaw != null
          ? CardFaceStyle.values.firstWhere(
              (v) => v.name == faceRaw,
              orElse: () => CardFaceStyle.classic,
            )
          : CardFaceStyle.classic,
      tableBackgroundStyle: tableRaw != null
          ? TableBackgroundStyle.values.firstWhere(
              (v) => v.name == tableRaw,
              orElse: () => TableBackgroundStyle.green,
            )
          : TableBackgroundStyle.green,
      klondikeDrawCount: rawDraw == 3 ? 3 : 1,
      spiderSuitCount: spiderSuitCount,
    );
  }

  Future<void> saveSettings(AppSettings v) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kSettings, jsonEncode({
      'languageCode': v.languageCode,
      'soundOn': v.soundOn,
      'vibrationOn': v.vibrationOn,
      'dealSpeed': v.dealSpeed.name,
      'themeMode': v.themeMode.index,
      'cardBack': v.cardBack,
      'cardFaceStyle': v.cardFaceStyle.name,
      'tableBackgroundStyle': v.tableBackgroundStyle.name,
      'klondikeDrawCount': v.klondikeDrawCount,
      'spiderSuitCount': v.spiderSuitCount,
    }));
  }

  /// Лучший результат ежедневной Косынки (минимум ходов) для даты `YYYY-MM-DD`, если есть.
  Future<int?> loadDailyKlondikeBestMoves(String ymd) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kDailyKlondikeMoves);
    if (raw == null) return null;
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return m[ymd] as int?;
  }

  /// Сохраняет лучший результат дня, если [moves] меньше текущего или рекорда ещё не было.
  /// Возвращает `true`, если запись обновилась (первый рекорд или улучшение).
  Future<bool> saveDailyKlondikeBestMovesIfBetter(String ymd, int moves) async {
    final p = await SharedPreferences.getInstance();
    final prev = await loadDailyKlondikeBestMoves(ymd);
    if (prev != null && moves >= prev) return false;
    final raw = p.getString(_kDailyKlondikeMoves);
    final Map<String, dynamic> m = raw == null ? {} : Map<String, dynamic>.from(jsonDecode(raw) as Map);
    m[ymd] = moves;
    await p.setString(_kDailyKlondikeMoves, jsonEncode(m));
    return true;
  }

  Future<AppStats> loadStats() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kStats);
    if (raw == null) return const AppStats();
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return AppStats.fromJson(m);
  }

  Future<void> saveStats(AppStats v) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kStats, jsonEncode(v.toJson()));
  }

  Future<void> saveKlondikeState(Map<String, dynamic> state) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kGameKlondike, jsonEncode(state));
  }

  Future<Map<String, dynamic>?> loadKlondikeState() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kGameKlondike);
    return raw == null ? null : (jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveSpiderState(Map<String, dynamic> state) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kGameSpider, jsonEncode(state));
  }

  Future<Map<String, dynamic>?> loadSpiderState() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kGameSpider);
    return raw == null ? null : (jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveFreecellState(Map<String, dynamic> state) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kGameFreecell, jsonEncode(state));
  }

  Future<Map<String, dynamic>?> loadFreecellState() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kGameFreecell);
    return raw == null ? null : (jsonDecode(raw) as Map<String, dynamic>);
  }
}
