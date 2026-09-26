import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rustore_review/flutter_rustore_review.dart' as rustore;
import 'package:in_app_review/in_app_review.dart' as gplay;

import 'store_target.dart';

/// Запрашивает оценку приложения в соответствующем магазине:
/// RuStore Review (`--flavor rustore`) или Google Play In-App Review
/// (`--flavor gplay --dart-define=STORE=gplay`).
///
/// Если магазин недоступен — тихо выходим.
Future<void> requestStoreReview() async {
  try {
    if (isRuStoreTarget) {
      await rustore.RustoreReviewClient.initialize();
      await rustore.RustoreReviewClient.request();
    } else {
      final review = gplay.InAppReview.instance;
      if (await review.isAvailable()) {
        await review.requestReview();
      }
    }
  } on PlatformException {
    // Магазин не установлен — диалог оценки не показываем.
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('Store review failed: $e\n$st');
    }
  }
}
