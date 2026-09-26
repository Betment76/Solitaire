import 'package:flutter/foundation.dart';
import 'package:yandex_mobileads/mobile_ads.dart';

/// Блок рекламы при открытии приложения.
/// Переопределение: `--dart-define=YANDEX_APP_OPEN_AD_UNIT_ID=...`
const String _kAppOpenId = String.fromEnvironment(
  'YANDEX_APP_OPEN_AD_UNIT_ID',
  defaultValue: 'R-M-19262021-4',
);

/// Тестовый блок из примеров SDK (если боевой не задан).
const String _kAppOpenDemo = 'demo-appopen-yandex';

/// Эффективный ad unit: при пустом или demo-значении — тестовый demo-блок.
String effectiveAppOpenAdUnitId() {
  if (_kAppOpenId.isEmpty || _kAppOpenId.startsWith('demo-')) {
    return _kAppOpenDemo;
  }
  return _kAppOpenId;
}

bool _appOpenHandledThisSession = false;

/// Загружает и показывает рекламу открытия. Один показ за сессию приложения.
///
/// Вызывать сразу после `runApp` (см. `main.dart`): загрузка идёт по сети,
/// поэтому показ случается уже после отрисовки первого экрана, а не накрывает
/// белый launch-экран.
Future<void> showAppOpenAdOncePerSession() async {
  if (_appOpenHandledThisSession) return;
  _appOpenHandledThisSession = true;
  final loader = AppOpenAdLoader();
  try {
    final ad = await loader.loadAd(
      adRequest: AdRequest(adUnitId: effectiveAppOpenAdUnitId()),
    );
    await ad.setAdEventListener(
      eventListener: AppOpenAdEventListener(),
    );
    await ad.show();
    await ad.waitForDismiss();
    await ad.destroy();
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('App open ad error: $e\n$st');
    }
  } finally {
    // Освобождаем нативные ресурсы лоадера, как у rewarded.
    loader.destroy();
  }
}
