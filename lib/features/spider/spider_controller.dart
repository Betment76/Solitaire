import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics/app_analytics.dart';
import '../../core/controllers/game_session_controller.dart';
import '../../core/audio/sound_service.dart';
import '../../core/models/app_stats.dart';
import '../../core/providers.dart';
import 'domain/spider_engine.dart';
import 'domain/spider_persistence.dart';
import 'domain/spider_state.dart';

final spiderControllerProvider =
    AsyncNotifierProvider<SpiderController, SpiderState>(SpiderController.new);

/// Контроллер состояния Паука: новая игра, ходы, undo/redo, сохранение, раздача.
class SpiderController extends AsyncNotifier<SpiderState>
    with GameSessionController<SpiderState> {
  final SpiderEngine _engine = SpiderEngine();

  /// Количество мастей в текущей партии (для проверки испытаний).
  int _currentSuitCount = 1;
  /// Секунды с экрана (для рекордов и экрана победы).
  int elapsedSeconds = 0;
  /// Бесплатные подсказки за партию (добор через rewarded).
  int _freeHintsRemaining = 3;

  @override
  Future<SpiderState> build() async {
    final saved = await ref.read(localStoreProvider).loadSpiderState();
    final restored = SpiderPersistence.fromMap(saved);
    // Настройки "Паук: количество мастей" влияют только на новую раздачу.
    final appSettings = await ref.read(settingsProvider.future);
    resetSession();
    // Победённую партию не восстанавливаем — «продолжать» нечего.
    if (restored != null && !restored.state.isWin) {
      restoreSession(undoBudget: restored.undoBudget);
      _freeHintsRemaining = restored.freeHintsRemaining;
      _currentSuitCount = restored.suitCount;
      return restored.state;
    }
    _freeHintsRemaining = 3;
    _currentSuitCount = appSettings.spiderSuitCount;
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
    resetSession();
    _freeHintsRemaining = 3;
    _currentSuitCount = appSettings.spiderSuitCount;
    state = AsyncData(next);
    await persist(next);
    unawaited(reportGameStart(SolitaireVariant.spider, spiderSuitCount: appSettings.spiderSuitCount));
  }

  void grantHintFromReward() => _freeHintsRemaining++;

  int get freeHintsRemaining => _freeHintsRemaining;

  /// Подсказка: бесплатные попытки или реклама ([needsReward]).
  ({SpiderHint? hint, bool needsReward, bool noMoves}) takeHintOrPrepareReward() {
    final current = state.asData?.value;
    if (current == null) return (hint: null, needsReward: false, noMoves: true);
    if (_freeHintsRemaining <= 0) {
      return (hint: null, needsReward: true, noMoves: false);
    }
    final h = _engine.hint(current);
    if (h == null) {
      return (hint: null, needsReward: false, noMoves: true);
    }
    _freeHintsRemaining--;
    final board = state.asData!.value;
    unawaited(persist(board));
    return (hint: h, needsReward: false, noMoves: false);
  }

  Future<void> dealFromStock() async {
    final current = state.asData?.value;
    if (current == null) return;
    final next = _engine.dealFromStock(current);
    applyMove(current, next);
  }

  Future<void> moveRun(int fromColumn, int fromIndex, int toColumn) async {
    final current = state.asData?.value;
    if (current == null) return;
    final next = _engine.moveRun(current, fromColumn, fromIndex, toColumn);
    applyMove(current, next);
  }

  Future<void> autoMoveTop(int fromColumn) async {
    final current = state.asData?.value;
    if (current == null) return;
    final next = _engine.autoMoveTop(current, fromColumn);
    applyMove(current, next);
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

  void syncElapsed(int seconds) => elapsedSeconds = seconds;

  bool canAutoFinish() {
    final current = state.asData?.value;
    if (current == null) return false;
    return _engine.canAutoFinish(current);
  }

  Future<void> autoFinishAll() async {
    final current = state.asData?.value;
    if (current == null) return;
    final next = _engine.autoFinishAll(current);
    applyMove(current, next);
  }

  @override
  void onMoveApplied(SpiderState previous, SpiderState next) {
    if (!previous.isWin && next.isWin) {
      ref.read(soundServiceProvider).play(SoundEvent.win);
      unawaited(ref.read(statsProvider.notifier).recordGameWin(
        SolitaireVariant.spider,
        moves: next.moves,
        elapsedSeconds: elapsedSeconds,
        usedUndo: usedUndo,
        spiderSuitCount: _currentSuitCount,
      ));
    }
  }

  @override
  Future<void> saveState(SpiderState value) {
    // Победа — партия закончена: сейв не храним.
    return value.isWin ? _clearSavedGame() : persist(value);
  }

  Future<void> _clearSavedGame() =>
      ref.read(localStoreProvider).clearSavedSpider();

  @override
  Future<void> persist(SpiderState value) async {
    await ref.read(localStoreProvider).saveSpiderState(
          SpiderPersistence.toMap(
            value,
            undoBudget: undoBudgetRemaining,
            freeHintsRemaining: _freeHintsRemaining,
            suitCount: _currentSuitCount,
          ),
        );
  }
}
