import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Кликабельный логотип МойСофт — по нажатию открывается каталог
/// разработчика в RuStore (правило «Логотип МойСофт»).
/// Эталон: Заготовки для проектов/clickable_logo_widget.dart.
class ClickableLogoWidget extends StatelessWidget {
  /// Путь к картинке логотипа в assets.
  final String logoAsset;

  /// URL при нажатии (по умолчанию каталог разработчика в RuStore).
  final String url;

  /// Высота логотипа в пикселях.
  final double height;

  /// Текст под логотипом (например «© 2025–2026» или null — не показывать).
  final String? copyrightText;

  const ClickableLogoWidget({
    super.key,
    this.logoAsset = 'assets/icons/logoms1.png',
    this.url = 'https://www.rustore.ru/catalog/developer/2pxggevr',
    this.height = 40,
    this.copyrightText = '© 2025–2026\nВсе права защищены',
  });

  Future<void> _openUrl() async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _openUrl,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Белое свечение по форме логотипа: два слоя размытого
                // белого силуэта — плотный у контура и мягкий по краям.
                ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Image.asset(
                    logoAsset,
                    height: height,
                    fit: BoxFit.contain,
                    color: Colors.white.withValues(alpha: 0.85),
                    colorBlendMode: BlendMode.srcIn,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
                ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                  child: Image.asset(
                    logoAsset,
                    height: height,
                    fit: BoxFit.contain,
                    color: Colors.white,
                    colorBlendMode: BlendMode.srcIn,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
                Image.asset(
                  logoAsset,
                  height: height,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => SizedBox(height: height),
                ),
              ],
            ),
          ),
          if (copyrightText != null && copyrightText!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              copyrightText!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
