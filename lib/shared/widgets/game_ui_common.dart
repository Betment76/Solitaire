import 'package:flutter/material.dart';

/// Метрика в верхней панели (счёт, время, ходы).
Widget metricWidget(String title, String value) {
  return Column(
    children: [
      Text(
        title,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

/// Цвет заливки верхних круглых кнопок — как у [bottomActionBar] (полупрозрачный зелёный).
Color _gameTopBarButtonFill() =>
    const Color(0xFF114C2F).withValues(alpha: 0.85);

/// Золотистая обводка панелей и круглых кнопок в игре.
Color get kGameTopBarGoldBorder => const Color(0xFFE8C547);

/// Круглая кнопка в верхней панели (меню / стиль и т.п.): как нижнее меню + золотая рамка.
Widget topCircleButton(
  IconData icon,
  VoidCallback onTap, {
  Color? backgroundColor,
  Color iconColor = Colors.white,
  double iconSize = 24,
  double tapPadding = 12,
}) {
  final fill = backgroundColor ?? _gameTopBarButtonFill();
  return Material(
    color: fill,
    shape: CircleBorder(
      side: BorderSide(color: kGameTopBarGoldBorder, width: 1.5),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.all(tapPadding),
        child: Icon(icon, size: iconSize, color: iconColor),
      ),
    ),
  );
}

/// Кнопка в нижней панели; [badge] — цифра в жёлтом кружке; [badgePlay] — та же капсула, внутри иконка play (реклама).
Widget bottomAction(
  IconData icon,
  String label,
  VoidCallback? onTap, {
  int? badge,
  bool badgePlay = false,
}) {
  final showBadge = badge != null || badgePlay;
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 22,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Icon(icon, size: 20, color: Colors.white),
                  if (showBadge)
                    Positioned(
                      right: -6,
                      top: -4,
                      // Одинаковый размер капсулы с цифрой; play меньше, чтобы не раздувать бейдж.
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFC107),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF114C2F), width: 1),
                        ),
                        constraints: const BoxConstraints(minWidth: 16),
                        alignment: Alignment.center,
                        child: badgePlay
                            ? const Icon(
                                Icons.play_arrow_rounded,
                                size: 8,
                                color: Color(0xFF1B1B1B),
                              )
                            : Text(
                                '$badge',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFF1B1B1B),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  height: 1,
                                ),
                              ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 10.5),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Нижняя панель с кнопками действий (та же полупрозрачная заливка + золотая рамка).
Widget bottomActionBar({
  required List<
          ({
            IconData icon,
            String label,
            VoidCallback? onTap,
            int? badge,
            bool badgePlay,
          })>
      actions,
}) {
  return Container(
    margin: const EdgeInsets.fromLTRB(8, 0, 8, 12),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFF114C2F).withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: kGameTopBarGoldBorder, width: 1.5),
    ),
    child: Row(
      children: [
        for (final action in actions) ...[
          Expanded(
            child: bottomAction(
              action.icon,
              action.label,
              action.onTap,
              badge: action.badge,
              badgePlay: action.badgePlay,
            ),
          ),
        ],
      ],
    ),
  );
}
