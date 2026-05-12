import 'package:flutter/foundation.dart';
import 'package:yandex_mobileads/mobile_ads.dart';

/// Реклама с вознаграждением (Yandex Mobile Ads SDK 8).
/// Общий блок (автофиниш, FreeCell, ежедневная вторая попытка и т.д.).
const String _kRewardedEnv =
    String.fromEnvironment('YANDEX_REWARDED_AD_UNIT_ID');

/// Подсказка в Косынке — переопределение: `--dart-define=YANDEX_REWARDED_KLONDIKE_HINT_ID=...`
const String _kKlondikeHintId = String.fromEnvironment(
  'YANDEX_REWARDED_KLONDIKE_HINT_ID',
  defaultValue: 'R-M-19262021-2',
);

/// Отмена в Косынке — `--dart-define=YANDEX_REWARDED_KLONDIKE_UNDO_ID=...`
const String _kKlondikeUndoId = String.fromEnvironment(
  'YANDEX_REWARDED_KLONDIKE_UNDO_ID',
  defaultValue: 'R-M-19262021-3',
);

/// Отмена хода в Пауке — `--dart-define=YANDEX_REWARDED_SPIDER_UNDO_ID=...`
const String _kSpiderUndoId = String.fromEnvironment(
  'YANDEX_REWARDED_SPIDER_UNDO_ID',
  defaultValue: 'R-M-19262021-3',
);

/// Подсказка в Пауке — если пусто, используется общий [YANDEX_REWARDED_AD_UNIT_ID].
const String _kSpiderHintId = String.fromEnvironment(
  'YANDEX_REWARDED_SPIDER_HINT_ID',
  defaultValue: '',
);

/// Отмена в FreeCell — `--dart-define=YANDEX_REWARDED_FREECELL_UNDO_ID=...`
const String _kFreecellUndoId = String.fromEnvironment(
  'YANDEX_REWARDED_FREECELL_UNDO_ID',
  defaultValue: 'R-M-19262021-3',
);

/// Тестовый блок из примеров SDK (если боевой не задан).
const String _kRewardedDemo = 'demo-rewarded-yandex';

/// Слот показа: разные рекламные блоки в кабинете РСЯ.
enum RewardedAdPlacement {
  /// Автофиниш, +ячейка FreeCell, daily retry и пр.
  generic,
  klondikeHint,
  klondikeUndo,
  spiderUndo,
  spiderHint,
  freecellUndo,
}

/// Эффективный ad unit: в debug при demo-* или пустом значении — тестовый demo-блок.
String effectiveRewardedAdUnitId([RewardedAdPlacement placement = RewardedAdPlacement.generic]) {
  final raw = switch (placement) {
    RewardedAdPlacement.generic => _kRewardedEnv,
    RewardedAdPlacement.klondikeHint => _kKlondikeHintId,
    RewardedAdPlacement.klondikeUndo => _kKlondikeUndoId,
    RewardedAdPlacement.spiderUndo => _kSpiderUndoId,
    RewardedAdPlacement.spiderHint =>
      _kSpiderHintId.isNotEmpty ? _kSpiderHintId : _kRewardedEnv,
    RewardedAdPlacement.freecellUndo => _kFreecellUndoId,
  };
  if (!kReleaseMode) {
    if (raw.isEmpty || raw.startsWith('demo-')) {
      return _kRewardedDemo;
    }
    return raw;
  }
  if (raw.isEmpty) return _kRewardedDemo;
  return raw;
}

/// Загружает и показывает rewarded; `true`, если пользователь получил награду.
Future<bool> showYandexRewardedAd({
  RewardedAdPlacement placement = RewardedAdPlacement.generic,
}) async {
  try {
    final loader = RewardedAdLoader();
    final ad = await loader.loadAd(
      adRequest: AdRequest(adUnitId: effectiveRewardedAdUnitId(placement)),
    );
    await ad.setAdEventListener(
      eventListener: RewardedAdEventListener(
        onRewarded: (_) {},
      ),
    );
    await ad.show();
    final reward = await ad.waitForDismiss();
    await ad.destroy();
    return reward != null;
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('Rewarded ad error: $e\n$st');
    }
    return false;
  }
}
