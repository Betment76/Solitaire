import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_table_background.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/providers.dart';

/// Экран статистики игрока.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(Localizations.localeOf(context));
    final stats = ref.watch(statsProvider).maybeWhen(
          data: (v) => v,
          orElse: () => null,
        );
    return DecoratedBox(
      decoration: kAppTableBackgroundDecoration,
      child: Theme(
        data: themeOnTable(context),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: Text(s.t('stats'))),
          body: stats == null
              ? const Center(child: CircularProgressIndicator(color: Colors.white70))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    ListTile(title: Text(s.t('wins')), trailing: Text('${stats.wins}')),
                    ListTile(title: Text(s.t('bestScore')), trailing: Text('${stats.bestScore}')),
                    ListTile(title: Text(s.t('winStreak')), trailing: Text('${stats.winStreak}')),
                    const Divider(height: 24, color: Colors.white24),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        s.t('statPerMode'),
                        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                    ListTile(title: Text(s.t('klondike')), trailing: Text('${stats.winsKlondike}')),
                    ListTile(title: Text(s.t('spider')), trailing: Text('${stats.winsSpider}')),
                    ListTile(title: Text(s.t('freecell')), trailing: Text('${stats.winsFreecell}')),
                  ],
                ),
        ),
      ),
    );
  }
}
