import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/achievement.dart';
import '../models/app_settings.dart';
import '../models/app_stats.dart';
import '../models/challenge.dart';
import '../models/record_entry.dart';
import '../models/unlockable_style.dart';

/// Репозиторий локального хранения настроек, статистики и сейва партии.
class LocalStore {
  static const _kSettings = 'settings';
  static const _kStats = 'stats';
  static const _kGameKlondike = 'game_state_klondike';
  static const _kGameSpider = 'game_state_spider';
  static const _kGameFreecell = 'game_state_freecell';
  static const _kDailyKlondikeMoves = 'daily_klondike_best_moves';
  static const _kChallenges = 'challenges';
  static const _kAchievements = 'achievements';
  static const _kStyles = 'unlockable_styles';
  static const _kDailyStats = 'daily_stats';
  static const _kFreecellBestMoves = 'daily_freecell_best_moves';
  static const _kFreecellBestTimes = 'daily_freecell_best_times';
  static const _kKlondikeBestTimes = 'daily_klondike_best_times';

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
      tableBackground: (m['tableBackground'] as String?) ?? 'bg_green',
      klondikeDrawCount: rawDraw == 3 ? 3 : 1,
      spiderSuitCount: spiderSuitCount,
      cardScale: (m['cardScale'] as num?)?.toDouble() ?? 1.0,
      showTimer: m['showTimer'] as bool? ?? true,
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
      'tableBackground': v.tableBackground,
      'klondikeDrawCount': v.klondikeDrawCount,
      'spiderSuitCount': v.spiderSuitCount,
      'cardScale': v.cardScale,
      'showTimer': v.showTimer,
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

  Future<bool> hasSavedKlondike() async {
    final p = await SharedPreferences.getInstance();
    return p.containsKey(_kGameKlondike);
  }

  Future<void> saveKlondikeState(Map<String, dynamic> state) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kGameKlondike, jsonEncode(state));
  }

  Future<Map<String, dynamic>?> loadKlondikeState() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kGameKlondike);
      return raw == null ? null : (jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<bool> hasSavedSpider() async {
    final p = await SharedPreferences.getInstance();
    return p.containsKey(_kGameSpider);
  }

  Future<void> saveSpiderState(Map<String, dynamic> state) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kGameSpider, jsonEncode(state));
  }

  Future<Map<String, dynamic>?> loadSpiderState() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kGameSpider);
      return raw == null ? null : (jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<bool> hasSavedFreecell() async {
    final p = await SharedPreferences.getInstance();
    return p.containsKey(_kGameFreecell);
  }

  Future<void> saveFreecellState(Map<String, dynamic> state) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kGameFreecell, jsonEncode(state));
  }

  Future<Map<String, dynamic>?> loadFreecellState() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kGameFreecell);
      return raw == null ? null : (jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  // --- Таблица рекордов (топ-10) ---

  static const _kRecords = 'records';
  static const int maxRecords = 10;

  Future<List<RecordEntry>> loadRecords() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kRecords);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => RecordEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Сохраняет [entry] в топ-10 для своего режима [RecordEntry.mode].
  Future<void> saveRecord(RecordEntry entry) async {
    final records = await loadRecords();
    final sameMode = [
      ...records.where((r) => r.mode == entry.mode),
      entry,
    ]..sort((a, b) => b.score.compareTo(a.score));
    final other = records.where((r) => r.mode != entry.mode);
    final top = [...other, ...sameMode.take(maxRecords)];
    final p = await SharedPreferences.getInstance();
    await p.setString(_kRecords, jsonEncode(top.map((e) => e.toJson()).toList()));
  }

  // --- Испытания (Challenge Mode) ---

  /// Загружает список испытаний. Если сохранённых нет — возвращает список по умолчанию.
  Future<List<Challenge>> loadChallenges() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kChallenges);
    if (raw != null) {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => Challenge.fromJson(e as Map<String, dynamic>)).toList();
    }
    return _defaultChallenges();
  }

  Future<void> saveChallenges(List<Challenge> challenges) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kChallenges, jsonEncode(challenges.map((e) => e.toJson()).toList()));
  }

  static List<Challenge> _defaultChallenges() {
    return [
      Challenge(id: 'ch_klondike_120', titleKey: 'ch_klondike_120_title', descriptionKey: 'ch_klondike_120_desc', mode: 'klondike', targetMoves: 120, unlockStyleId: 'back_gold'),
      Challenge(id: 'ch_spider_4suits', titleKey: 'ch_spider_4suits_title', descriptionKey: 'ch_spider_4suits_desc', mode: 'spider', fourSuits: true, unlockStyleId: 'back_dark'),
      Challenge(id: 'ch_freecell_nocells', titleKey: 'ch_freecell_nocells_title', descriptionKey: 'ch_freecell_nocells_desc', mode: 'freecell', noCells: true, unlockStyleId: 'bg_cosmos'),
      Challenge(id: 'ch_klondike_3min', titleKey: 'ch_klondike_3min_title', descriptionKey: 'ch_klondike_3min_desc', mode: 'klondike', targetTime: 180, unlockStyleId: 'back_red'),
      Challenge(id: 'ch_spider_1suit', titleKey: 'ch_spider_1suit_title', descriptionKey: 'ch_spider_1suit_desc', mode: 'spider', targetMoves: 150, unlockStyleId: 'bg_wood'),
      Challenge(id: 'ch_freecell_fast', titleKey: 'ch_freecell_fast_title', descriptionKey: 'ch_freecell_fast_desc', mode: 'freecell', targetTime: 300, unlockStyleId: 'back_purple'),
      Challenge(id: 'ch_klondike_undo', titleKey: 'ch_klondike_undo_title', descriptionKey: 'ch_klondike_undo_desc', mode: 'klondike', noUndo: true, unlockStyleId: 'bg_gold'),
      Challenge(id: 'ch_spider_fast', titleKey: 'ch_spider_fast_title', descriptionKey: 'ch_spider_fast_desc', mode: 'spider', targetTime: 600, unlockStyleId: 'back_green'),
      // Универсальные — подходят для любого режима, разблокируют фоны стола.
      Challenge(id: 'ch_any_win_50', titleKey: 'ch_any_win_50_title', descriptionKey: 'ch_any_win_50_desc', mode: 'any', targetMoves: 300, unlockStyleId: 'bg_blue'),
      Challenge(id: 'ch_any_5min', titleKey: 'ch_any_5min_title', descriptionKey: 'ch_any_5min_desc', mode: 'any', targetTime: 300, unlockStyleId: 'bg_dark'),
    ];
  }

  // --- Достижения ---

  Future<List<Achievement>> loadAchievements() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kAchievements);
    if (raw != null) {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => Achievement.fromJson(e as Map<String, dynamic>)).toList();
    }
    return _defaultAchievements();
  }

  Future<void> saveAchievements(List<Achievement> achievements) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kAchievements, jsonEncode(achievements.map((e) => e.toJson()).toList()));
  }

  static List<Achievement> _defaultAchievements() {
    return [
      Achievement(id: 'achv_100_klondike', titleKey: 'achv_100_klondike_title', descriptionKey: 'achv_100_klondike_desc', category: AchievementCategory.wins, targetValue: 100, icon: '👑'),
      Achievement(id: 'achv_50_freecell', titleKey: 'achv_50_freecell_title', descriptionKey: 'achv_50_freecell_desc', category: AchievementCategory.wins, targetValue: 50, icon: '🧊'),
      Achievement(id: 'achv_50_spider', titleKey: 'achv_50_spider_title', descriptionKey: 'achv_50_spider_desc', category: AchievementCategory.wins, targetValue: 50, icon: '🕷'),
      Achievement(id: 'achv_3min', titleKey: 'achv_3min_title', descriptionKey: 'achv_3min_desc', category: AchievementCategory.speed, targetValue: 1, icon: '⚡'),
      Achievement(id: 'achv_streak_10', titleKey: 'achv_streak_10_title', descriptionKey: 'achv_streak_10_desc', category: AchievementCategory.streak, targetValue: 10, icon: '🔥'),
      Achievement(id: 'achv_no_undo', titleKey: 'achv_no_undo_title', descriptionKey: 'achv_no_undo_desc', category: AchievementCategory.special, targetValue: 1, icon: '💪'),
      Achievement(id: 'achv_1_win', titleKey: 'achv_1_win_title', descriptionKey: 'achv_1_win_desc', category: AchievementCategory.wins, targetValue: 1, icon: '🎉'),
      Achievement(id: 'achv_streak_5', titleKey: 'achv_streak_5_title', descriptionKey: 'achv_streak_5_desc', category: AchievementCategory.streak, targetValue: 5, icon: '🔥'),
    ];
  }

  // --- Разблокируемые стили ---

  Future<List<UnlockableStyle>> loadStyles() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kStyles);
    if (raw != null) {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => UnlockableStyle.fromJson(e as Map<String, dynamic>)).toList();
    }
    return _defaultStyles();
  }

  Future<void> saveStyles(List<UnlockableStyle> styles) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kStyles, jsonEncode(styles.map((e) => e.toJson()).toList()));
  }

  static List<UnlockableStyle> _defaultStyles() {
    return [
      UnlockableStyle(id: 'back_blue', displayNameKey: 'style_back_blue', type: StyleType.cardBack, isUnlocked: true),
      UnlockableStyle(id: 'back_red', displayNameKey: 'style_back_red', type: StyleType.cardBack),
      UnlockableStyle(id: 'back_gold', displayNameKey: 'style_back_gold', type: StyleType.cardBack),
      UnlockableStyle(id: 'back_dark', displayNameKey: 'style_back_dark', type: StyleType.cardBack),
      UnlockableStyle(id: 'back_purple', displayNameKey: 'style_back_purple', type: StyleType.cardBack),
      UnlockableStyle(id: 'back_green', displayNameKey: 'style_back_green', type: StyleType.cardBack),
      UnlockableStyle(id: 'bg_green', displayNameKey: 'style_bg_green', type: StyleType.tableBackground, isUnlocked: true),
      UnlockableStyle(id: 'bg_blue', displayNameKey: 'style_bg_blue', type: StyleType.tableBackground),
      UnlockableStyle(id: 'bg_dark', displayNameKey: 'style_bg_dark', type: StyleType.tableBackground),
      UnlockableStyle(id: 'bg_cosmos', displayNameKey: 'style_bg_cosmos', type: StyleType.tableBackground),
      UnlockableStyle(id: 'bg_wood', displayNameKey: 'style_bg_wood', type: StyleType.tableBackground),
      UnlockableStyle(id: 'bg_gold', displayNameKey: 'style_bg_gold', type: StyleType.tableBackground),
    ];
  }

  // --- FreeCell: Daily Challenge ---

  Future<int?> loadDailyFreecellBestMoves(String ymd) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kFreecellBestMoves);
    if (raw == null) return null;
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return m[ymd] as int?;
  }

  Future<bool> saveDailyFreecellBestMovesIfBetter(String ymd, int moves) async {
    final p = await SharedPreferences.getInstance();
    final prev = await loadDailyFreecellBestMoves(ymd);
    if (prev != null && moves >= prev) return false;
    final raw = p.getString(_kFreecellBestMoves);
    final Map<String, dynamic> m = raw == null ? {} : Map<String, dynamic>.from(jsonDecode(raw) as Map);
    m[ymd] = moves;
    await p.setString(_kFreecellBestMoves, jsonEncode(m));
    return true;
  }

  Future<int?> loadDailyFreecellBestTime(String ymd) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kFreecellBestTimes);
    if (raw == null) return null;
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return m[ymd] as int?;
  }

  Future<bool> saveDailyFreecellBestTimeIfBetter(String ymd, int seconds) async {
    final p = await SharedPreferences.getInstance();
    final prev = await loadDailyFreecellBestTime(ymd);
    if (prev != null && seconds >= prev) return false;
    final raw = p.getString(_kFreecellBestTimes);
    final Map<String, dynamic> m = raw == null ? {} : Map<String, dynamic>.from(jsonDecode(raw) as Map);
    m[ymd] = seconds;
    await p.setString(_kFreecellBestTimes, jsonEncode(m));
    return true;
  }

  // --- Klondike: рекорд времени в Daily Challenge ---

  Future<int?> loadDailyKlondikeBestTime(String ymd) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kKlondikeBestTimes);
    if (raw == null) return null;
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return m[ymd] as int?;
  }

  Future<bool> saveDailyKlondikeBestTimeIfBetter(String ymd, int seconds) async {
    final p = await SharedPreferences.getInstance();
    final prev = await loadDailyKlondikeBestTime(ymd);
    if (prev != null && seconds >= prev) return false;
    final raw = p.getString(_kKlondikeBestTimes);
    final Map<String, dynamic> m = raw == null ? {} : Map<String, dynamic>.from(jsonDecode(raw) as Map);
    m[ymd] = seconds;
    await p.setString(_kKlondikeBestTimes, jsonEncode(m));
    return true;
  }

  // --- Дневная статистика (победы по дням) ---

  /// Загружает количество побед за последние 30 дней в формате `{ 'YYYY-MM-DD': wins }`.
  Future<Map<String, int>> loadDailyStats() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kDailyStats);
    if (raw == null) return {};
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return m.map((k, v) => MapEntry(k, v as int));
  }

  /// Добавляет +1 победу для указанной даты.
  Future<void> incrementDailyWin(String ymd) async {
    final stats = await loadDailyStats();
    stats[ymd] = (stats[ymd] ?? 0) + 1;
    // Оставляем только последние 90 дней
    final keys = stats.keys.toList()..sort();
    while (keys.length > 90) {
      stats.remove(keys.removeAt(0));
    }
    final p = await SharedPreferences.getInstance();
    await p.setString(_kDailyStats, jsonEncode(stats));
  }
}
