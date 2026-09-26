import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'analytics/app_analytics.dart';
import 'data/local_store.dart';
import 'models/achievement.dart';
import 'models/app_settings.dart';
import 'models/app_stats.dart';
import 'models/challenge.dart';
import 'leaderboard_score.dart';
import 'models/record_entry.dart';
import 'models/unlockable_style.dart';

final localStoreProvider = Provider<LocalStore>((_) => LocalStore());

/// Провайдер настроек приложения с автосохранением.
class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async => ref.read(localStoreProvider).loadSettings();

  Future<void> save(AppSettings value) async {
    state = AsyncData(value);
    await ref.read(localStoreProvider).saveSettings(value);
  }
}

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

/// Провайдер статистики приложения с автосохранением.
class StatsNotifier extends AsyncNotifier<AppStats> {
  @override
  Future<AppStats> build() async => ref.read(localStoreProvider).loadStats();

  Future<void> save(AppStats value) async {
    state = AsyncData(value);
    await ref.read(localStoreProvider).saveStats(value);
  }

  /// Статистика с диска — надёжнее, чем только in-memory, если провайдер ещё не прогрелся.
  Future<AppStats> _loadFresh() async => ref.read(localStoreProvider).loadStats();

  /// Победа: общий счётчик, по режиму, серия; для Косынки ещё [bestScore].
  Future<void> recordGameWin(
    SolitaireVariant mode, {
    int? klondikeScore,
    bool dailyChallenge = false,
    int? moves,
    int? elapsedSeconds,
    bool usedUndo = true,
    bool usedFreeCells = false,
    int? spiderSuitCount,
  }) async {
    final settings = await ref.read(settingsProvider.future);
    final effectiveElapsed = settings.showTimer ? elapsedSeconds : null;

    final s = await _loadFresh();
    final nextBest = klondikeScore != null && klondikeScore > s.bestScore ? klondikeScore : s.bestScore;
    await save(
      s.copyWith(
        wins: s.wins + 1,
        winsKlondike: mode == SolitaireVariant.klondike ? s.winsKlondike + 1 : s.winsKlondike,
        winsSpider: mode == SolitaireVariant.spider ? s.winsSpider + 1 : s.winsSpider,
        winsFreecell: mode == SolitaireVariant.freecell ? s.winsFreecell + 1 : s.winsFreecell,
        bestScore: nextBest,
        winStreak: s.winStreak + 1,
      ),
    );
    unawaited(reportGameWin(mode, klondikeScore: klondikeScore, dailyChallenge: dailyChallenge));

    await _incrementAchievementForWin(
      ref,
      mode,
      elapsedSeconds: effectiveElapsed,
      usedUndo: usedUndo,
    );
    final now = DateTime.now();
    final ymd = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    await ref.read(localStoreProvider).incrementDailyWin(ymd);
    await _checkChallengesOnWin(
      ref,
      mode,
      moves: moves,
      elapsedSeconds: effectiveElapsed,
      usedUndo: usedUndo,
      usedFreeCells: usedFreeCells,
      spiderSuitCount: spiderSuitCount,
    );
    if (settings.showTimer) {
      await _saveLeaderboardRecord(
        ref,
        mode,
        klondikeScore: klondikeScore,
        moves: moves,
        elapsedSeconds: effectiveElapsed,
      );
    }
  }

  /// Топ-10 рекордов по режиму после победы.
  Future<void> _saveLeaderboardRecord(
    Ref ref,
    SolitaireVariant mode, {
    int? klondikeScore,
    int? moves,
    int? elapsedSeconds,
  }) async {
    final now = DateTime.now();
    final ymd =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final entry = RecordEntry(
      score: leaderboardScore(
        klondikeScore: klondikeScore,
        moves: moves,
        elapsedSeconds: elapsedSeconds,
      ),
      mode: _challengeModeString(mode),
      date: ymd,
      moves: moves,
    );
    await ref.read(localStoreProvider).saveRecord(entry);
    if (ref.mounted) ref.invalidate(recordsProvider);
  }

  /// Проверка всех испытаний после победы.
  Future<void> _checkChallengesOnWin(
    Ref ref,
    SolitaireVariant mode, {
    int? moves,
    int? elapsedSeconds,
    bool usedUndo = true,
    bool usedFreeCells = false,
    int? spiderSuitCount = 1,
  }) async {
    final challenges = await ref.read(challengesProvider.future);
    if (!ref.mounted) return;
    for (final c in challenges) {
      if (c.status == ChallengeStatus.completed) continue;
      // 'any' подходит для любого режима
      if (c.mode != 'any' && _challengeModeString(mode) != c.mode) continue;

      // Проверяем все условия испытания.
      if (c.noUndo && usedUndo) continue;
      if (c.noCells && usedFreeCells) continue;
      if (c.fourSuits && (spiderSuitCount == null || spiderSuitCount < 4)) continue;
      if (c.targetMoves != null) {
        final m = moves;
        if (m == null || m > c.targetMoves!) continue;
      }
      if (c.targetTime != null) {
        final t = elapsedSeconds;
        if (t == null || t > c.targetTime!) continue;
      }

      // Все условия выполнены — испытание пройдено.
      await ref.read(challengesProvider.notifier).completeChallenge(c.id);
      if (!ref.mounted) return;

      if (c.unlockStyleId != null) {
        await ref.read(stylesProvider.notifier).unlock(c.unlockStyleId!);
        if (ref.mounted) {
          ref.read(unlockFlashProvider.notifier).show(c.unlockStyleId!);
        }
      }
    }
  }

  static String _challengeModeString(SolitaireVariant mode) {
    switch (mode) {
      case SolitaireVariant.klondike: return 'klondike';
      case SolitaireVariant.spider: return 'spider';
      case SolitaireVariant.freecell: return 'freecell';
    }
  }

  Future<void> _incrementAchievementForWin(
    Ref ref,
    SolitaireVariant mode, {
    int? elapsedSeconds,
    bool usedUndo = true,
  }) async {
    final achievements = ref.read(achievementsProvider.notifier);
    await achievements.increment('achv_1_win');
    if (mode == SolitaireVariant.klondike) {
      await achievements.increment('achv_100_klondike');
    } else if (mode == SolitaireVariant.freecell) {
      await achievements.increment('achv_50_freecell');
    } else if (mode == SolitaireVariant.spider) {
      await achievements.increment('achv_50_spider');
    }
    final s = await _loadFresh();
    if (s.winStreak >= 5) await achievements.increment('achv_streak_5');
    if (s.winStreak >= 10) await achievements.increment('achv_streak_10');
    if (elapsedSeconds != null && elapsedSeconds < 180) {
      await achievements.increment('achv_3min');
    }
    if (!usedUndo) {
      await achievements.increment('achv_no_undo');
    }
  }

  /// Новая игра при незаконченной партии — серию побед обнуляем.
  Future<void> recordGameAbandoned() async {
    final s = await _loadFresh();
    if (s.winStreak == 0) return;
    await save(s.copyWith(winStreak: 0));
  }
}

final statsProvider = AsyncNotifierProvider<StatsNotifier, AppStats>(StatsNotifier.new);

/// Сигнал с главного меню: при открытии Косынки сразу загрузить ежедневную раздачу.
class KlondikeOpenDailyNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// Запланировать ежедневную раздачу при следующем открытии экрана Косынки.
  void scheduleOpenDaily() => state = true;

  /// Сбросить флаг после обработки на экране Косынки.
  void consume() => state = false;
}

final klondikeOpenDailyProvider = NotifierProvider<KlondikeOpenDailyNotifier, bool>(KlondikeOpenDailyNotifier.new);

/// С главного меню: открыть FreeCell с ежедневной раздачей.
class FreecellOpenDailyNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void scheduleOpenDaily() => state = true;

  void consume() => state = false;
}

final freecellOpenDailyProvider =
    NotifierProvider<FreecellOpenDailyNotifier, bool>(FreecellOpenDailyNotifier.new);

/// Краткое уведомление о победе в ежедневной партии (SnackBar на экране Косынки).
class DailyWinFlash {
  const DailyWinFlash({required this.moves, required this.newBestForDay});
  final int moves;
  final bool newBestForDay;
}

class DailyWinFlashNotifier extends Notifier<DailyWinFlash?> {
  @override
  DailyWinFlash? build() => null;

  void show(DailyWinFlash v) => state = v;

  void clear() => state = null;
}

final dailyWinFlashProvider = NotifierProvider<DailyWinFlashNotifier, DailyWinFlash?>(DailyWinFlashNotifier.new);

final dailyFreecellWinFlashProvider =
    NotifierProvider<DailyWinFlashNotifier, DailyWinFlash?>(DailyWinFlashNotifier.new);

/// Лучший результат ежедневной Косынки (минимум ходов) для даты `YYYY-MM-DD`.
final dailyKlondikeBestMovesProvider = FutureProvider.autoDispose.family<int?, String>((ref, ymd) async {
  return ref.watch(localStoreProvider).loadDailyKlondikeBestMoves(ymd);
});

/// Модель сохранённой партии для диалога продолжения.
class SavedGameInfo {
  const SavedGameInfo({required this.route, required this.variant});
  final String route;
  final String variant;
}

/// Провайдер, проверяющий наличие сохранённых партий (Косынка, Паук, FreeCell).
final hasSavedGameProvider = FutureProvider<SavedGameInfo?>((ref) async {
  final store = ref.watch(localStoreProvider);
  if (await store.hasSavedKlondike()) return const SavedGameInfo(route: '/klondike', variant: 'klondike');
  if (await store.hasSavedSpider()) return const SavedGameInfo(route: '/spider', variant: 'spider');
  if (await store.hasSavedFreecell()) return const SavedGameInfo(route: '/freecell', variant: 'freecell');
  return null;
});

/// Таблица рекордов (топ-10).
final recordsProvider = FutureProvider<List<RecordEntry>>((ref) async {
  return ref.watch(localStoreProvider).loadRecords();
});

// --- Испытания (Challenge Mode) ---

class ChallengesNotifier extends AsyncNotifier<List<Challenge>> {
  @override
  Future<List<Challenge>> build() async => ref.read(localStoreProvider).loadChallenges();

  Future<void> save(List<Challenge> v) async {
    state = AsyncData(v);
    await ref.read(localStoreProvider).saveChallenges(v);
  }

  /// Пометить испытание как пройденное.
  Future<void> completeChallenge(String challengeId) async {
    final list = [...(await future)];
    final idx = list.indexWhere((c) => c.id == challengeId);
    if (idx == -1) return;
    list[idx] = list[idx].copyWith(status: ChallengeStatus.completed);
    await save(list);
  }
}

final challengesProvider =
    AsyncNotifierProvider<ChallengesNotifier, List<Challenge>>(ChallengesNotifier.new);

// --- Достижения ---

class AchievementsNotifier extends AsyncNotifier<List<Achievement>> {
  @override
  Future<List<Achievement>> build() async => ref.read(localStoreProvider).loadAchievements();

  Future<void> save(List<Achievement> v) async {
    state = AsyncData(v);
    await ref.read(localStoreProvider).saveAchievements(v);
  }

  /// Увеличить счётчик достижения на [increment]. Если цель достигнута — разблокировать.
  Future<void> increment(String achievementId, {int increment = 1}) async {
    final list = [...(await future)];
    final idx = list.indexWhere((a) => a.id == achievementId);
    if (idx == -1) return;
    final a = list[idx];
    if (a.isUnlocked) return;
    final next = a.currentValue + increment;
    final unlocked = next >= a.targetValue;
    list[idx] = a.copyWith(currentValue: next, isUnlocked: unlocked);
    await save(list);
  }
}

final achievementsProvider =
    AsyncNotifierProvider<AchievementsNotifier, List<Achievement>>(AchievementsNotifier.new);

/// ID разблокированного стиля для показа всплывашки.
class UnlockFlashNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void show(String styleId) => state = styleId;

  void clear() => state = null;
}

final unlockFlashProvider = NotifierProvider<UnlockFlashNotifier, String?>(UnlockFlashNotifier.new);

// --- Разблокируемые стили ---

class StylesNotifier extends AsyncNotifier<List<UnlockableStyle>> {
  @override
  Future<List<UnlockableStyle>> build() async => ref.read(localStoreProvider).loadStyles();

  Future<void> save(List<UnlockableStyle> v) async {
    state = AsyncData(v);
    await ref.read(localStoreProvider).saveStyles(v);
  }

  Future<void> unlock(String styleId) async {
    final list = [...(await future)];
    final idx = list.indexWhere((s) => s.id == styleId);
    if (idx == -1) return;
    list[idx] = list[idx].copyWith(isUnlocked: true);
    await save(list);
  }
}

final stylesProvider =
    AsyncNotifierProvider<StylesNotifier, List<UnlockableStyle>>(StylesNotifier.new);

/// FreeCell: лучшие ходы для ежедневной раздачи.
final dailyFreecellBestMovesProvider =
    FutureProvider.autoDispose.family<int?, String>((ref, ymd) async {
  return ref.watch(localStoreProvider).loadDailyFreecellBestMoves(ymd);
});

/// FreeCell: лучшее время для ежедневной раздачи.
final dailyFreecellBestTimeProvider =
    FutureProvider.autoDispose.family<int?, String>((ref, ymd) async {
  return ref.watch(localStoreProvider).loadDailyFreecellBestTime(ymd);
});

/// Klondike: лучшее время для ежедневной раздачи.
final dailyKlondikeBestTimeProvider =
    FutureProvider.autoDispose.family<int?, String>((ref, ymd) async {
  return ref.watch(localStoreProvider).loadDailyKlondikeBestTime(ymd);
});

/// Дневная статистика (победы по дням).
final dailyStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  return ref.watch(localStoreProvider).loadDailyStats();
});
