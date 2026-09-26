import 'package:flutter/material.dart';

/// Зелёная рамка вокруг легальной цели при drag-and-drop.
Widget legalDropGlow(Widget child) {
  return Stack(
    clipBehavior: Clip.none,
    fit: StackFit.passthrough,
    children: [
      child,
      Positioned.fill(
        child: IgnorePointer(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFF4CAF50),
                  width: 2.5,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
