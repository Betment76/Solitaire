import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yandex_mobileads/mobile_ads.dart';

import 'core/analytics/app_analytics.dart';
import 'core/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Инициализация рекламного SDK Яндекса. Ошибки не валят запуск приложения.
  try {
    await YandexAds.initialize();
    // В debug — логи SDK (в т.ч. загрузка реального блока), как в доке Яндекса.
    if (kDebugMode) await YandexAds.setLogging(true);
  } catch (_) {}
  // RuStore / продакшн: AppMetrica вместо Firebase (см. --dart-define=APPMETRICA_API_KEY).
  await initAppMetricaIfConfigured();
  // Запускаем приложение внутри ProviderScope для Riverpod.
  runApp(const ProviderScope(child: SolitaireApp()));
}
