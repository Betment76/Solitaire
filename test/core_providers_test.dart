import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solitaire/core/data/local_store.dart';
import 'package:solitaire/core/models/app_settings.dart';
import 'package:solitaire/core/models/app_stats.dart';
import 'package:solitaire/core/providers.dart';

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  test('StatsNotifier: recordGameWin увеличивает победы', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final s0 = await c.read(statsProvider.future);
    expect(s0.wins, 0);
    await c.read(statsProvider.notifier).recordGameWin(SolitaireVariant.freecell);
    final s1 = await c.read(statsProvider.future);
    expect(s1.wins, 1);
    expect(s1.winsFreecell, 1);
  });

  test('StatsNotifier: recordGameWin обновляет bestScore для Косынки', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(statsProvider.future);
    await c.read(statsProvider.notifier).recordGameWin(SolitaireVariant.klondike, klondikeScore: 999);
    final s = await c.read(statsProvider.future);
    expect(s.bestScore, 999);
  });

  test('StatsNotifier: recordGameAbandoned обнуляет серию', () async {
    await LocalStore().saveStats(const AppStats(wins: 1, winsKlondike: 1, winStreak: 4));
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(statsProvider.future);
    await c.read(statsProvider.notifier).recordGameAbandoned();
    final s = await c.read(statsProvider.future);
    expect(s.winStreak, 0);
  });

  test('StatsNotifier: recordGameAbandoned при нулевой серии', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(statsProvider.future);
    await c.read(statsProvider.notifier).recordGameAbandoned();
  });

  test('SettingsNotifier: save', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(settingsProvider.notifier).save(const AppSettings(languageCode: 'en', soundOn: false));
    final s = await c.read(settingsProvider.future);
    expect(s.languageCode, 'en');
    expect(s.soundOn, isFalse);
  });

  test('KlondikeOpenDailyNotifier schedule/consume', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(klondikeOpenDailyProvider.notifier).scheduleOpenDaily();
    expect(c.read(klondikeOpenDailyProvider), isTrue);
    c.read(klondikeOpenDailyProvider.notifier).consume();
    expect(c.read(klondikeOpenDailyProvider), isFalse);
  });

  test('DailyWinFlashNotifier show/clear', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(dailyWinFlashProvider.notifier).show(const DailyWinFlash(moves: 11, newBestForDay: false));
    expect(c.read(dailyWinFlashProvider)?.moves, 11);
    c.read(dailyWinFlashProvider.notifier).clear();
    expect(c.read(dailyWinFlashProvider), isNull);
  });

  test('dailyKlondikeBestMovesProvider читает LocalStore', () async {
    await LocalStore().saveDailyKlondikeBestMovesIfBetter('2030-06-15', 77);
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final v = await c.read(dailyKlondikeBestMovesProvider('2030-06-15').future);
    expect(v, 77);
  });
}
