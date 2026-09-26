import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_table_background.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/models/record_entry.dart';
import '../../core/providers.dart';
import '../../shared/widgets/daily_wins_chart.dart';

/// Экран статистики игрока с таблицей рекордов (топ-10 по режиму).
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  /// Показать диалог таблицы рекордов.
  static void showRecordsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const _RecordsDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(Localizations.localeOf(context));
    final stats = ref.watch(statsProvider).maybeWhen(
          data: (v) => v,
          orElse: () => null,
        );
    final records = ref.watch(recordsProvider).maybeWhen(
          data: (v) => v,
          orElse: () => List<RecordEntry>.empty(),
        );
    final dailyStats = ref.watch(dailyStatsProvider).maybeWhen(
          data: (v) => v,
          orElse: () => const <String, int>{},
        );
    return DecoratedBox(
      decoration: kAppTableBackgroundDecoration,
      child: Theme(
        data: themeOnTable(context),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(s.t('stats')),
            actions: [
              if (records.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.emoji_events_rounded),
                  tooltip: s.t('recordTitle'),
                  onPressed: () => showRecordsDialog(context),
                ),
            ],
          ),
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
                    const Divider(height: 24, color: Colors.white24),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        s.t('dailyStatsChart'),
                        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: DailyWinsChart(winsByDay: dailyStats),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton.icon(
                        onPressed: records.isEmpty ? null : () => showRecordsDialog(context),
                        icon: const Icon(Icons.emoji_events_rounded),
                        label: Text(s.t('recordTitle')),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

String _modeLabel(AppStrings s, String mode) {
  switch (mode) {
    case 'klondike':
      return s.t('klondike');
    case 'spider':
      return s.t('spider');
    case 'freecell':
      return s.t('freecell');
    default:
      return mode;
  }
}

/// Диалог таблицы рекордов с фильтром по режиму.
class _RecordsDialog extends ConsumerStatefulWidget {
  const _RecordsDialog();

  @override
  ConsumerState<_RecordsDialog> createState() => _RecordsDialogState();
}

class _RecordsDialogState extends ConsumerState<_RecordsDialog> {
  String? _modeFilter;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(Localizations.localeOf(context));
    final records = ref.watch(recordsProvider).maybeWhen(
          data: (v) => v,
          orElse: () => List<RecordEntry>.empty(),
        );
    List<RecordEntry> filtered;
    if (_modeFilter == null) {
      filtered = [...records]..sort((a, b) => b.score.compareTo(a.score));
    } else {
      filtered = records.where((r) => r.mode == _modeFilter).toList()
        ..sort((a, b) => b.score.compareTo(a.score));
    }

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD66E)),
          const SizedBox(width: 8),
          Expanded(child: Text(s.t('recordTitle'))),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 6,
              children: [
                FilterChip(
                  label: Text(s.t('recordAllModes')),
                  selected: _modeFilter == null,
                  onSelected: (_) => setState(() => _modeFilter = null),
                ),
                FilterChip(
                  label: Text(s.t('klondike')),
                  selected: _modeFilter == 'klondike',
                  onSelected: (_) => setState(() => _modeFilter = 'klondike'),
                ),
                FilterChip(
                  label: Text(s.t('spider')),
                  selected: _modeFilter == 'spider',
                  onSelected: (_) => setState(() => _modeFilter = 'spider'),
                ),
                FilterChip(
                  label: Text(s.t('freecell')),
                  selected: _modeFilter == 'freecell',
                  onSelected: (_) => setState(() => _modeFilter = 'freecell'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (filtered.isEmpty)
              Text(s.t('dailyNoBestYet'))
            else
              SizedBox(
                height: 320,
                child: SingleChildScrollView(
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(Colors.white10),
                    columns: [
                      DataColumn(label: Text(s.t('recordRank'), style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text(s.t('recordScore'), style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text(s.t('recordMoves'), style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text(s.t('recordMode'), style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text(s.t('recordDate'), style: const TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: List.generate(filtered.length, (i) {
                      final r = filtered[i];
                      return DataRow(cells: [
                        DataCell(Text('#${i + 1}')),
                        DataCell(Text('${r.score}')),
                        DataCell(Text(r.moves != null ? '${r.moves}' : '-')),
                        DataCell(Text(_modeLabel(s, r.mode))),
                        DataCell(Text(r.date)),
                      ]);
                    }),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
      ],
    );
  }
}
