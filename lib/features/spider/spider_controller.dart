import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics/app_analytics.dart';
import '../../core/audio/sound_service.dart';
import '../../core/models/app_stats.dart';
import '../../core/providers.dart';
import 'domain/spider_engine.dart';
import 'domain/spider_persistence.dart';
import 'domain/spider_state.dart';

final spiderControllerProvider =
    AsyncNotifierProvider<SpiderController, SpiderState>(SpiderController.new);

/// Контроллер состояния Паука: новая игра, ходы, undo/redo, сохранение, раздача.
class SpiderController extends AsyncNotifier<SpiderState> {
  final SpiderEngine _engine = SpiderEngine();
  final List<SpiderState> _undo = <SpiderState>[];
  final List<SpiderState> _redo = <SpiderState>[];

  /// Бесплатные отмены за текущую партию (добор через rewarded).
  int _undoBudget = 5;
  /// Бесплатные подсказки за партию (добор через rewarded).
  int _freeHintsRemaining = 3;

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  bool get canUndoWithBudget => canUndo && _undoBudget > 0;
  /// Оставшиеся бесплатные отмены (добор через rewarded).
  int get undoBudgetRemaining => _undoBudget;

  @override
  Future<SpiderState> build() async {
    final saved = await ref.read(localStoreProvider).loadSpiderState();
    final restored = SpiderPersistence.fromMap(saved);
    // Настройки "Паук: количество мастей" влияют только на новую раздачу.
    final appSettings = await ref.read(settingsProvider.future);
    _undo.clear();
    _redo.clear();
    if (restored != null) {
      _undoBudget = restored.undoBudget;
      _freeHintsRemaining = restored.freeHintsRemaining;
      return restored.state;
    }
    _undoBudget = 5;
    _freeHintsRemaining = 3;
    return _engine.newGame(
      seed: DateTime.now().millisecondsSinceEpoch,
      suitCount: appSettings.spiderSuitCount,
    );
  }

  Future<void> newGame() async {
    final cur = state.asData?.value;
    if (cur != null && !cur.isWin) {
      unawaited(ref.read(statsProvider.notifier).recordGameAbandoned());
    }
    // Применяем текущие настройки к новой раздаче.
    final appSettings = await ref.read(settingsProvider.future);
    final next = _engine.newGame(
      seed: DateTime.now().millisecondsSinceEpoch,
      suitCount: appSettings.spiderSuitCount,
    );
    _undo.clear();
    _redo.clear();
    _undoBudget = 5;
    _freeHintsRemaining = 3;
    state = AsyncData(next);
    await _persist(next);
    unawaited(reportGameStart(SolitaireVariant.spider, spiderSuitCount: appSettings.spiderSuitCount));
  }

  void grantUndoFromReward() => _undoBudget++;

  void grantHintFromReward() => _freeHintsRemaining++;

  int get freeHintsRemaining => _freeHintsRemaining;

  /// Подсказка: бесплатные попытки или реклама ([needsReward]).
  ({String? tag, bool needsReward, bool noMoves}) takeHintOrPrepareReward() {
    final current = state.asData?.value;
    if (current == null) return (tag: null, needsReward: false, noMoves: true);
    if (_freeHintsRemaining <= 0) {
      return (tag: null, needsReward: true, noMoves: false);
    }
    final tag = _engine.hint(current);
    if (tag == null) {
      return (tag: null, needsReward: false, noMoves: true);
    }
    _freeHintsRemaining--;
    final board = state.asData!.value;
    unawaited(_persist(board));
    return (tag: tag, needsReward: false, noMoves: false);
  }

  Future<void> undo() async {
    final current = state.asData?.value;
    if (current == null || _undo.isEmpty) return;
    if (_undoBudget <= 0) return;
    _undoBudget--;
    final prev = _undo.removeLast();
    _redo.add(current);
    state = AsyncData(prev);
    await _persist(prev);
  }

  Future<void> redo() async {
    final current = state.asData?.value;
    if (current == null || _redo.isEmpty) return;
    final next = _redo.removeLast();
    _undo.add(current);
    state = AsyncData(next);
    await _persist(next);
  }

  Future<void> dealFromStock() async {
    final current = state.asData?.value;
    if (current == null) return;
    final next = _engine.dealFromStock(current);
    _apply(current, next);
  }

  Future<void> moveRun(int fromColumn, int fromIndex, int toColumn) async {
    final current = state.asData?.value;
    if (current == null) return;
    final next = _engine.moveRun(current, fromColumn, fromIndex, toColumn);
    _apply(current, next);
  }

  Future<void> autoMoveTop(int fromColumn) async {
    final current = state.asData?.value;
    if (current == null) return;
    final next = _engine.autoMoveTop(current, fromColumn);
    _apply(current, next);
  }

  bool canDragRun(int fromColumn, int fromIndex) {
    final current = state.asData?.value;
    if (current == null) return false;
    return _engine.canDragRun(current, fromColumn, fromIndex);
  }

  bool canDealFromStock() {
    final current = state.asData?.value;
    if (current == null) return false;
    final next = _engine.dealFromStock(current);
    return !identical(next, current);
  }

  bool canMove(int fromColumn, int fromIndex, int toColumn) {
    final current = state.asData?.value;
    if (current == null) return false;
    final next = _engine.moveRun(current, fromColumn, fromIndex, toColumn);
    return !identical(next, current);
  }

  void _apply(SpiderState current, SpiderState next) {
    if (identical(next, current)) return;
    if (!current.isWin && next.isWin) {
      ref.read(soundServiceProvider).play(SoundEvent.win);
      unawaited(ref.read(statsProvider.notifier).recordGameWin(SolitaireVariant.spider));
    }
    _undo.add(current);
    _redo.clear();
    state = AsyncData(next);
    unawaited(_persist(next));
  }

  Future<void> _persist(SpiderState value) async {
    await ref.read(localStoreProvider).saveSpiderState(
          SpiderPersistence.toMap(
            value,
            undoBudget: _undoBudget,
            freeHintsRemaining: _freeHintsRemaining,
          ),
        );
  }
}
