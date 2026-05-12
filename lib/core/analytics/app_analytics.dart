import 'package:appmetrica_plugin/appmetrica_plugin.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/app_stats.dart';

/// Ключ из консоли AppMetrica; приоритет у `--dart-define=APPMETRICA_API_KEY=...`.
/// Если dart-define не передан, используем встроенный ключ для локального/ручного запуска.
const String kAppmetricaApiKey = String.fromEnvironment(
  'APPMETRICA_API_KEY',
  defaultValue: '7d0d2b12-9f05-4c67-8b91-bdc83a7d282a',
);

bool get isAppAnalyticsEnabled => kAppmetricaApiKey.isNotEmpty;

/// Вызывает AppMetrica; в тестах и без платформы канал недоступен — не пробрасываем ошибку.
Future<void> _runAppMetrica(Future<void> Function() fn) async {
  if (!isAppAnalyticsEnabled) return;
  try {
    await fn();
  } on PlatformException {
    // В `flutter test` и без нативного плагина канал недоступен — норма, не спамим в лог.
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('AppMetrica: $e\n$st');
    }
  }
}

/// Активация SDK; без ключа приложение работает без сетевой аналитики.
Future<void> initAppMetricaIfConfigured() async {
  if (!isAppAnalyticsEnabled) {
    if (kDebugMode) debugPrint('AppMetrica: ключ не передан — метрики отключены.');
    return;
  }
  await _runAppMetrica(() async {
    await AppMetrica.activate(
      AppMetricaConfig(
        kAppmetricaApiKey,
        // Включаем максимум доступной авто-аналитики SDK.
        advIdentifiersTracking: true,
        anrMonitoring: true,
        appOpenTrackingEnabled: true,
        crashReporting: true,
        flutterCrashReporting: true,
        nativeCrashReporting: true,
        dataSendingEnabled: true,
        revenueAutoTrackingEnabled: true,
        sessionsAutoTrackingEnabled: true,
        locationTracking: true,
        // Подробные логи оставляем только в debug, чтобы не шуметь в release.
        logs: kDebugMode,
      ),
    );
  });
}

Future<void> reportGameWin(
  SolitaireVariant mode, {
  int? klondikeScore,
  bool dailyChallenge = false,
}) async {
  await _runAppMetrica(() async {
    await AppMetrica.reportEventWithMap('game_win', {
      'mode': _mode(mode),
      'daily_challenge': dailyChallenge,
      if (klondikeScore != null) 'score': klondikeScore,
    });
  });
}

Future<void> reportGameStart(
  SolitaireVariant mode, {
  bool dailyChallenge = false,
  int? spiderSuitCount,
}) async {
  await _runAppMetrica(() async {
    await AppMetrica.reportEventWithMap('game_start', {
      'mode': _mode(mode),
      'daily_challenge': dailyChallenge,
      if (spiderSuitCount != null) 'spider_suit_count': spiderSuitCount,
    });
  });
}

String _mode(SolitaireVariant v) => switch (v) {
      SolitaireVariant.klondike => 'klondike',
      SolitaireVariant.spider => 'spider',
      SolitaireVariant.freecell => 'freecell',
    };
