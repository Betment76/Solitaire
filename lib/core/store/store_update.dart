import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rustore_update/flutter_rustore_update.dart' as rustore;
import 'package:in_app_update/in_app_update.dart' as gplay;

import 'store_target.dart';

bool _updatePromptShownThisSession = false;

/// Проверяет обновление в соответствующем магазине и запускает штатный
/// сценарий обновления: RuStore (`--flavor rustore`) или
/// Google Play In-App Updates (`--flavor gplay --dart-define=STORE=gplay`).
///
/// Один вызов за сессию; на устройствах без магазина (и в тестах) ошибки
/// проглатываются — игра работает без обновлений.
Future<void> promptStoreUpdateIfAvailable() async {
  if (_updatePromptShownThisSession) return;
  _updatePromptShownThisSession = true;
  try {
    if (isRuStoreTarget) {
      final info = await rustore.RustoreUpdateClient.info();
      final availability = rustore.UpdateAvailability.fromValue(info.updateAvailability);
      if (availability == rustore.UpdateAvailability.available) {
        await rustore.RustoreUpdateClient.immediate();
      }
    } else {
      final info = await gplay.InAppUpdate.checkForUpdate();
      if (info.updateAvailability == gplay.UpdateAvailability.updateAvailable) {
        await gplay.InAppUpdate.performImmediateUpdate();
      }
    }
  } on PlatformException {
    // Магазин не установлен или канал недоступен — обновление не предлагаем.
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('Store update check failed: $e\n$st');
    }
  }
}
