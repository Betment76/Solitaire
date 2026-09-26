import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_table_background.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/providers.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(Localizations.localeOf(context));
    final achievementsAsync = ref.watch(achievementsProvider);
    return DecoratedBox(
      decoration: kAppTableBackgroundDecoration,
      child: Theme(
        data: themeOnTable(context),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: Text(s.t('achievements'))),
          body: achievementsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: Colors.white70)),
            error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: Colors.white70))),
            data: (achievements) {
              final unlocked = achievements.where((a) => a.isUnlocked).length;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      '${s.t('achievements')} $unlocked / ${achievements.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: Colors.white24),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      itemCount: achievements.length,
                      itemBuilder: (context, index) {
                        final a = achievements[index];
                        final unlockedStyle = a.isUnlocked;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Card(
                            color: unlockedStyle
                                ? const Color(0xFF1A4A2A).withValues(alpha: 0.7)
                                : Colors.white.withValues(alpha: 0.08),
                            child: ListTile(
                              leading: Text(a.icon, style: const TextStyle(fontSize: 32)),
                              title: Text(
                                s.t(a.titleKey),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: unlockedStyle ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 2),
                                  Text(
                                    s.t(a.descriptionKey),
                                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                                  ),
                                  const SizedBox(height: 6),
                                  LinearProgressIndicator(
                                    value: a.progress,
                                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                                    color: unlockedStyle ? const Color(0xFFFFD700) : const Color(0xFF1FA463),
                                  ),
                                ],
                              ),
                              trailing: unlockedStyle
                                  ? const Icon(Icons.emoji_events, color: Color(0xFFFFD700))
                                  : Text(
                                      '${a.currentValue}/${a.targetValue}',
                                      style: const TextStyle(color: Colors.white60, fontSize: 13),
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
