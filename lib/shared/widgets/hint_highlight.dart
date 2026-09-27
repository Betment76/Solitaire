import 'package:flutter/material.dart';

/// Жёлтая подложка-подсветка для слота подсказки (мигание в Косынке и Пауке).
Widget hintYellowOverlay(Widget child) {
  return Stack(
    clipBehavior: Clip.none,
    fit: StackFit.passthrough,
    children: [
      child,
      Positioned.fill(
        child: IgnorePointer(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ColoredBox(
              color: const Color(0xFFFFEB3B).withValues(alpha: 0.55),
            ),
          ),
        ),
      ),
    ],
  );
}
