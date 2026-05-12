import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:yandex_mobileads/mobile_ads.dart';

/// Нижний адаптивный баннер Яндекса (inline): ширина — экран, высоту SDK подбирает до 50 dp.
class YandexStickyBanner extends StatefulWidget {
  const YandexStickyBanner({super.key});

  @override
  State<YandexStickyBanner> createState() => _YandexStickyBannerState();
}

class _YandexStickyBannerState extends State<YandexStickyBanner> {
  /// Боевой блок sticky-баннера из кабинета РСЯ.
  static const String _productionAdUnitId = 'R-M-19262021-1';
  static const String _adUnitFromEnv =
      String.fromEnvironment('YANDEX_STICKY_AD_UNIT_ID');

  /// Debug/Profile: всегда реальный блок; `demo-*` из dart-define игнорируются.
  /// Release: пустой define → боевой ID; иначе значение из define.
  static String _effectiveAdUnitId() {
    if (!kReleaseMode) {
      if (_adUnitFromEnv.isEmpty || _adUnitFromEnv.startsWith('demo-')) {
        return _productionAdUnitId;
      }
      return _adUnitFromEnv;
    }
    if (_adUnitFromEnv.isEmpty) return _productionAdUnitId;
    return _adUnitFromEnv;
  }

  BannerAd? _banner;
  StreamSubscription<BannerAdLoadState>? _stateSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBanner());
  }

  Future<void> _loadBanner() async {
    try {
      final width = MediaQuery.sizeOf(context).width.toInt();
      // Адаптивный inline: SDK сам выбирает размер в пределах maxHeight (dp).
      const maxH = 50;
      final banner = BannerAd(
        adSize: BannerAdSize.inline(width: width, maxHeight: maxH),
      );
      _stateSub = banner.loadStateStream.listen((state) {
        if (!mounted) return;
        if (state is BannerAdLoadStateError) {
          // При ошибке загрузки просто скрываем баннер.
          setState(() => _banner = null);
        }
      });
      await banner.load(AdRequest(adUnitId: _effectiveAdUnitId()));
      if (!mounted) {
        await banner.destroy();
        return;
      }
      setState(() => _banner = banner);
    } catch (_) {
      // В тестах/без плагина просто скрываем баннер.
      if (mounted) setState(() => _banner = null);
    }
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _banner?.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_banner == null) {
      return const SizedBox.shrink();
    }
    return SafeArea(
      top: false,
      child: Center(
        // Размер считает SDK в рамках inline(maxHeight: 50).
        child: AdWidget(bannerAd: _banner!),
      ),
    );
  }
}
