import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_table_background.dart';
import '../../core/l10n/app_strings.dart';

/// Временный экран игрового режима с базовыми действиями MVP.
class GameStubScreen extends StatefulWidget {
  const GameStubScreen({super.key, required this.titleKey, required this.seedPrefix});

  final String titleKey;
  final String seedPrefix;

  @override
  State<GameStubScreen> createState() => _GameStubScreenState();
}

class _GameStubScreenState extends State<GameStubScreen> {
  int _seconds = 0;
  int _score = 0;
  int _moves = 0;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _action() => setState(() {
        _moves++;
        _score += 5;
      });

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(Localizations.localeOf(context));
    return DecoratedBox(
      decoration: kAppTableBackgroundDecoration,
      child: Theme(
        data: Theme.of(context).copyWith(
          scaffoldBackgroundColor: Colors.transparent,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: Colors.white,
            scrolledUnderElevation: 0,
          ),
          textTheme: Theme.of(context).textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: Text(s.t(widget.titleKey))),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Базовые игровые метрики для MVP-экрана режима.
                Text('${s.t('score')}: $_score'),
                Text('${s.t('time')}: ${_seconds}s'),
                Text('${s.t('moves')}: $_moves'),
                Text('${s.t('seed')}: ${widget.seedPrefix}-${DateTime.now().day}'),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Act(title: s.t('newGame'), onTap: _action),
                    _Act(title: s.t('restart'), onTap: _action),
                    _Act(title: s.t('autoFinish'), onTap: _action),
                    _Act(title: s.t('hint'), onTap: _action),
                    _Act(title: s.t('undo'), onTap: _action),
                    _Act(title: s.t('redo'), onTap: _action),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Act extends StatelessWidget {
  const _Act({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton(
        style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
        onPressed: onTap,
        child: Text(title),
      );
}
