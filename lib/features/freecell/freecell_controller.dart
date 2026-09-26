import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics/app_analytics.dart';
import '../../core/audio/sound_service.dart';
import '../../core/daily_seed.dart';
import '../../core/models/app_stats.dart';
import '../../core/providers.dart';
import 'domain/freecell_engine.dart';
import 'domain/freecell_persistence.dart';
import 'domain/freecell_state.dart';

final freecellControllerProvider =
    AsyncNotifierProvider<FreecellController, FreecellState>(FreecellController.new);

/// Контроллер состояния FreeCell: новая игра, ходы, undo/redo, сохранение.
class FreecellController extends AsyncNotifier<FreecellState> {
  final FreecellEngine _engine = FreecellEngine();
  final List<FreecellState> _undo = <FreecellState>[];
  final List<FreecellState> _redo = <FreecellState>[];

  /// Бесплатные отмены за партию (5), дальше — rewarded.
  int _undoBudget = 5;
  /// Был ли хоть раз использован Undo за эту партию.
  bool _usedUndo = false;
  /// Секунды с экрана (для рекордов и экрана победы).
  int elapsedSeconds = 0;
  /// Использовались ли ячейки free cell (для проверки испытания noCells).
  bool _usedFreeCells = false;
  /// Дата ежедневной сессии `YYYY-MM-DD`.
  String? _dailySessionYmd;

  bool get isDailySession => _dailySessionYmd != null;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  bool get canUndoWithBudget => canUndo && _undoBudget > 0;
  int get undoBudgetRemaining => _undoBudget;

  static String _todayYmd() => DateTime.now().toIso8601String().substring(0, 10);

  @override
  Future<FreecellState> build() async {
    final saved = await ref.read(localStoreProvider).loadFreecellState();
    final restored = FreecellPersistence.fromMap(saved);
    _undo.clear();
    _redo.clear();
    if (restored != null) {
      _undoBudget = restored.undoBudget;
      _usedUndo = false;
      _usedFreeCells = false;
      _dailySessionYmd = restored.dailyYmd;
      return restored.state;
    }
    _undoBudget = 5;
    _usedUndo = false;
    _usedFreeCells = false;
    return _engine.newGame(seed: DateTime.now().millisecondsSinceEpoch);
  }

  /// Ежедневная раздача FreeCell (фиксированный seed от даты).
  Future<void> startDailyChallenge() async {
    final cur = state.asData?.value;
    if (cur != null && !cur.isWin) {
      unawaited(ref.read(statsProvider.notifier).recordGameAbandoned());
    }
    _dailySessionYmd = _todayYmd();
    final seed = freecellDailySeed(_dailySessionYmd!);
    final next = _engine.newGame(seed: seed);
    _undo.clear();
    _redo.clear();
    _undoBudget = 5;
    _usedUndo = false;
    _usedFreeCells = false;
    elapsedSeconds = 0;
    state = AsyncData(next);
    await _persist(next);
    unawaited(reportGameStart(SolitaireVariant.freecell, dailyChallenge: true));
  }

  Future<void> newGame() async {
    _dailySessionYmd = null;
    final cur = state.asData?.value;
    if (cur != null && !cur.isWin) {
      unawaited(ref.read(statsProvider.notifier).recordGameAbandoned());
    }
    final next = _engine.newGame(seed: DateTime.now().millisecondsSinceEpoch);
    _undo.clear();
    _redo.clear();
    _undoBudget = 5;
    _usedUndo = false;
    _usedFreeCells = false;
    state = AsyncData(next);
    await _persist(next);
    unawaited(reportGameStart(SolitaireVariant.freecell));
  }

  /// Одна бесплатная добавка ячейки за партию (если [freeExtraCellUnlockPending]).
  void addExtraFreeCellSlotFree() {
    final c = state.asData?.value;
    if (c == null || c.extraFreeCellSlots >= FreecellPersistence.maxExtraFreeCells) {
      return;
    }
    if (!c.freeExtraCellUnlockPending) return;
    final next = c.copyWith(
      freeCells: [...c.freeCells, null],
      extraFreeCellSlots: c.extraFreeCellSlots + 1,
      freeExtraCellUnlockPending: false,
    );
    _apply(c, next);
  }

  /// Ячейка после rewarded (до лимита [FreecellPersistence.maxExtraFreeCells]).
  void addExtraFreeCellSlotFromAd() {
    final c = state.asData?.value;
    if (c == null || c.extraFreeCellSlots >= FreecellPersistence.maxExtraFreeCells) {
      return;
    }
    final next = c.copyWith(
      freeCells: [...c.freeCells, null],
      extraFreeCellSlots: c.extraFreeCellSlots + 1,
    );
    _apply(c, next);
  }

  /// +1 отмена после просмотра рекламы.
  void grantUndoFromReward() => _undoBudget++;

  Future<void> undo() async {
    final current = state.asData?.value;
    if (current == null || _undo.isEmpty) return;
    if (_undoBudget <= 0) return;
    _undoBudget--;
    _usedUndo = true;
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

  Future<void> moveTableauToTableau(int fromCol, int toCol, {int? fromCardIndex}) async {
    final current = state.asData?.value;
    if (current == null) return;
    final next = _engine.moveTableauToTableau(current, fromCol, toCol, fromCardIndex: fromCardIndex);
    _apply(current, next);
  }

  Future<void> moveTableauToFreeCell(int fromCol, int cellIndex) async {
    final current = state.asData?.value;
    if (current == null) return;
    final next = _engine.moveTableauToFreeCell(current, fromCol, cellIndex);
    if (!identical(next, current)) _usedFreeCells = true;
    _apply(current, next);
  }

  Future<void> moveFreeCellToTableau(int cellIndex, int toCol) async {
    final current = state.asData?.value;
    if (current == null) return;
    final next = _engine.moveFreeCellToTableau(current, cellIndex, toCol);
    _apply(current, next);
  }

  Future<void> moveTableauToFoundation(int fromCol) async {
    final current = state.asData?.value;
    if (current == null) return;
    final next = _engine.moveTableauToFoundation(current, fromCol);
    _apply(current, next);
  }

  Future<void> moveFreeCellToFoundation(int cellIndex) async {
    final current = state.asData?.value;
    if (current == null) return;
    final next = _engine.moveFreeCellToFoundation(current, cellIndex);
    _apply(current, next);
  }

  Future<void> autoMoveTableauTop(int fromCol) async {
    final current = state.asData?.value;
    if (current == null) return;
    final next = _engine.autoMoveTableauTop(current, fromCol);
    _apply(current, next);
  }

  bool canMoveTableauToTableau(int fromCol, int toCol, {int? fromCardIndex}) {
    final current = state.asData?.value;
    if (current == null) return false;
    return !identical(_engine.moveTableauToTableau(current, fromCol, toCol, fromCardIndex: fromCardIndex), current);
  }

  bool canMoveFreeCellToTableau(int cellIndex, int toCol) {
    final current = state.asData?.value;
    if (current == null) return false;
    return !identical(_engine.moveFreeCellToTableau(current, cellIndex, toCol), current);
  }

  bool canMoveTableauToFoundation(int fromCol) {
    final current = state.asData?.value;
    if (current == null) return false;
    return !identical(_engine.moveTableauToFoundation(current, fromCol), current);
  }

  bool canMoveFreeCellToFoundation(int cellIndex) {
    final current = state.asData?.value;
    if (current == null) return false;
    return !identical(_engine.moveFreeCellToFoundation(current, cellIndex), current);
  }

  Future<void> autoFinishAll() async {
    final current = state.asData?.value;
    if (current == null) return;
    if (!_engine.canAutoFinish(current)) return;
    final next = _engine.autoFinishAll(current);
    _apply(current, next);
  }

  /// Возвращает подсказку от движка или null.
  FreecellHint? hint() {
    final current = state.asData?.value;
    if (current == null) return null;
    return _engine.hint(current);
  }

  bool canAutoFinish() {
    final current = state.asData?.value;
    if (current == null) return false;
    return _engine.canAutoFinish(current);
  }

  void syncElapsed(int seconds) => elapsedSeconds = seconds;

  void _apply(FreecellState current, FreecellState next) {
    if (identical(next, current)) return;
    if (!current.isWin && next.isWin) {
      ref.read(soundServiceProvider).play(SoundEvent.win);
      final day = _dailySessionYmd;
      unawaited(ref.read(statsProvider.notifier).recordGameWin(
        SolitaireVariant.freecell,
        moves: next.moves,
        elapsedSeconds: elapsedSeconds,
        usedUndo: _usedUndo,
        usedFreeCells: _usedFreeCells,
        dailyChallenge: day != null,
      ));
      if (day != null) {
        unawaited(_finishDailyWin(day, next.moves, elapsedSeconds));
      }
    }
    _undo.add(current);
    _redo.clear();
    state = AsyncData(next);
    unawaited(_persist(next));
  }

  Future<void> _finishDailyWin(String day, int moves, int seconds) async {
    final store = ref.read(localStoreProvider);
    final improvedMoves = await store.saveDailyFreecellBestMovesIfBetter(day, moves);
    await store.saveDailyFreecellBestTimeIfBetter(day, seconds);
    ref.read(dailyFreecellWinFlashProvider.notifier).show(
          DailyWinFlash(moves: moves, newBestForDay: improvedMoves),
        );
    ref.invalidate(dailyFreecellBestMovesProvider(day));
    ref.invalidate(dailyFreecellBestTimeProvider(day));
  }

  Future<void> _persist(FreecellState value) async {
    await ref.read(localStoreProvider).saveFreecellState(
          FreecellPersistence.toMap(
            value,
            undoBudget: _undoBudget,
            dailyYmd: _dailySessionYmd,
          ),
        );
  }
}
