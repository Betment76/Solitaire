import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'analytics/app_analytics.dart';
import 'data/local_store.dart';
import 'models/app_settings.dart';
import 'models/app_stats.dart';

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
  }) async {
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

/// Лучший результат ежедневной Косынки (минимум ходов) для даты `YYYY-MM-DD`.
final dailyKlondikeBestMovesProvider = FutureProvider.autoDispose.family<int?, String>((ref, ymd) async {
  return ref.watch(localStoreProvider).loadDailyKlondikeBestMoves(ymd);
});
