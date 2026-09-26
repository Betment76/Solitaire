import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_table_background.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/models/challenge.dart';
import '../../core/providers.dart';

class ChallengeScreen extends ConsumerWidget {
  const ChallengeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(Localizations.localeOf(context));
    final challengesAsync = ref.watch(challengesProvider);
    final stylesAsync = ref.watch(stylesProvider);

    return DecoratedBox(
      decoration: kAppTableBackgroundDecoration,
      child: Theme(
        data: themeOnTable(context),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: Text(s.t('challenges'))),
          body: challengesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: Colors.white70)),
            error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: Colors.white70))),
            data: (challenges) {
              return stylesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: Colors.white70)),
                error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: Colors.white70))),
                data: (styles) {
                  final unlockedStyleIds = styles
                      .where((st) => st.isUnlocked)
                      .map((st) => st.id)
                      .toSet();
                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: challenges.length,
                    itemBuilder: (context, index) {
                      final c = challenges[index];
                      final isCompleted =
                          c.status == ChallengeStatus.completed;
                      final styleUnlocked = c.unlockStyleId != null &&
                          unlockedStyleIds.contains(c.unlockStyleId);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Card(
                          color: isCompleted
                              ? const Color(0xFF1A4A2A).withValues(alpha: 0.7)
                              : Colors.white.withValues(alpha: 0.08),
                          child: ListTile(
                            leading: Icon(
                              isCompleted
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: isCompleted
                                  ? const Color(0xFF1FA463)
                                  : Colors.white38,
                              size: 32,
                            ),
                            title: Text(
                              s.t(c.titleKey),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              s.t(c.descriptionKey),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            trailing: styleUnlocked
                                ? const Icon(Icons.lock_open,
                                    color: Color(0xFFFFD700))
                                : (c.unlockStyleId != null
                                    ? const Icon(Icons.lock,
                                        color: Colors.white38)
                                    : null),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
