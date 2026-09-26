import 'package:flutter/material.dart';

/// Столбчатый график побед за последние [days] дней.
class DailyWinsChart extends StatelessWidget {
  const DailyWinsChart({
    super.key,
    required this.winsByDay,
    this.days = 14,
  });

  final Map<String, int> winsByDay;
  final int days;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final labels = <String>[];
    final values = <int>[];
    for (var i = days - 1; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      final ymd =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      labels.add('${d.day}');
      values.add(winsByDay[ymd] ?? 0);
    }
    final maxV = values.fold<int>(0, (a, b) => a > b ? a : b);
    final cap = maxV < 1 ? 1 : maxV;

    return SizedBox(
      height: 132,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(days, (i) {
          final h = 88.0 * (values[i] / cap);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (values[i] > 0)
                    Text(
                      '${values[i]}',
                      style: const TextStyle(color: Colors.white54, fontSize: 9),
                    ),
                  const SizedBox(height: 2),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: h.clamp(4, 88),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    labels[i],
                    style: const TextStyle(color: Colors.white38, fontSize: 9),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
