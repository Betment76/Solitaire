import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/providers.dart';

/// Главный экран выбора режима пасьянса.
class SelectorScreen extends ConsumerWidget {
  const SelectorScreen({super.key});

  // Главный экран: более темный зеленый фон в тон иконок режимов.
  static const BoxDecoration _selectorBackgroundDecoration = BoxDecoration(
    gradient: LinearGradient(
      // Зеленое сукно: насыщенный темно-зеленый без болотного оттенка.
      colors: [Color(0xFF146B3A), Color(0xFF0E542F)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(Localizations.localeOf(context));
    // Дата для ежедневного сида и строки рекорда (один день — одна раздача).
    final dateSeed = DateTime.now().toIso8601String().substring(0, 10);
    final bestAsync = ref.watch(dailyKlondikeBestMovesProvider(dateSeed));
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SizedBox.expand(
        child: DecoratedBox(
          decoration: _selectorBackgroundDecoration,
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        s.t('selectorTitle'),
                        style: Theme.of(
                          context,
                        ).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      // Карточки режимов с короткими описаниями.
                      _ModeTile(
                        title: s.t('klondike'),
                        subtitle: s.t('modeKlondikeSubtitle'),
                        imagePath: 'assets/icon/icon2 (2).png',
                        onTap: () => Navigator.pushNamed(context, '/klondike'),
                      ),
                      _ModeTile(
                        title: s.t('spider'),
                        subtitle: s.t('modeSpiderSubtitle'),
                        imagePath: 'assets/icon/icon.png',
                        onTap: () => Navigator.pushNamed(context, '/spider'),
                      ),
                      _ModeTile(
                        title: s.t('freecell'),
                        subtitle: s.t('modeFreecellSubtitle'),
                        imagePath: 'assets/icon/icon3.png',
                        onTap: () => Navigator.pushNamed(context, '/freecell'),
                      ),
                      const SizedBox(height: 6),
                      Card(
                        color: Colors.white.withValues(alpha: 0.08),
                        child: ListTile(
                          onTap: () {
                            ref.read(klondikeOpenDailyProvider.notifier).scheduleOpenDaily();
                            Navigator.pushNamed(context, '/klondike');
                          },
                          title: Text(s.t('dailyChallenge'), style: const TextStyle(color: Colors.white)),
                          subtitle: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${s.t('seed')}: $dateSeed', style: const TextStyle(color: Colors.white70)),
                              const SizedBox(height: 4),
                              bestAsync.when(
                                data: (b) => Text(
                                  b == null
                                      ? s.t('dailyNoBestYet')
                                      : s.t('dailyBestLine').replaceAll('{m}', '$b'),
                                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                                ),
                                loading: () => const SizedBox.shrink(),
                                error: (_, __) => const SizedBox.shrink(),
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD66E)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                              onPressed: () => Navigator.pushNamed(context, '/stats'),
                              icon: const Icon(Icons.bar_chart_rounded),
                              label: Text(s.t('stats')),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                              onPressed: () => Navigator.pushNamed(context, '/settings'),
                              icon: const Icon(Icons.settings_rounded),
                              label: Text(s.t('settings')),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.title,
    required this.subtitle,
    required this.imagePath,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String imagePath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Card(
        color: Colors.white.withValues(alpha: 0.09),
        child: SizedBox(
          height: 152,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: SizedBox(
                        width: 132,
                        height: 132,
                        child: Transform.scale(
                          // Легкий zoom убирает черный кант вокруг золотой рамки.
                          scale: 1.12,
                          child: Image.asset(
                            imagePath,
                            fit: BoxFit.cover,
                            errorBuilder: (context, _, __) => Container(
                              color: Colors.white12,
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.broken_image_rounded,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      // Высота ряда ограничена картинкой 132 — длинные подписи ужимаем без overflow.
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 36 / 2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: const TextStyle(color: Colors.white70, fontSize: 30 / 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Colors.white70),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
