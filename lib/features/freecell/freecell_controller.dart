import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics/app_analytics.dart';
import '../../core/controllers/game_session_controller.dart';
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
class FreecellController extends AsyncNotifier<FreecellState>
    with GameSessionController<FreecellState> {
  final FreecellEngine _engine = FreecellEngine();

  /// Секунды с экрана (для рекордов и экрана победы).
  int elapsedSeconds = 0;
  /// Использовались ли ячейки free cell (для проверки испытания noCells).
  bool _usedFreeCells = false;
  /// Дата ежедневной сессии `YYYY-MM-DD`.
  String? _dailySessionYmd;

  bool get isDailySession => _dailySessionYmd != null;

  static String _todayYmd() => DateTime.now().toIso8601String().substring(0, 10);

  @override
  Future<FreecellState> build() async {
    final saved = await ref.read(localStoreProvider).loadFreecellState();
    final restored = FreecellPersistence.fromMap(saved);
    resetSession();
    // Победённую партию не восстанавливаем — «продолжать» нечего.
    if (restored != null && !restored.state.isWin) {
      restoreSession(undoBudget: restored.undoBudget);
      _usedFreeCells = false;
      _dailySessionYmd = restored.dailyYmd;
      return restored.state;
    }
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
    resetSession();
    _usedFreeCells = false;
    elapsedSeconds = 0;
    state = AsyncData(next);
    await persist(next);
    unawaited(reportGameStart(SolitaireVariant.freecell, dailyChallenge: true));
  }

  Future<void> newGame() async {
    _dailySessionYmd = null;
    final cur = state.asData?.value;
    if (cur != null && !cur.isWin) {
      unawaited(ref.read(statsProvider.notifier).recordGameAbandoned());
    }
    final next = _engine.newGame(seed: DateTime.now().millisecondsSinceEpoch);
    resetSession();
    _usedFreeCells = false;
    state = AsyncData(next);
    await persist(next);
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
    applyMove(c, next);
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
    applyMove(c, next);
  }

  Future<void> moveTableauToTableau(int fromCol, int toCol, {int? fromCardIndex}) async {
    final current = state.asData?.value;
    if (current == null) return;
    final next = _engine.moveTableauToTableau(current, fromCol, toCol, fromCardIndex: fromCardIndex);
    applyMove(current, next);
  }

  Future<void> moveTableauToFreeCell(int fromCol, int cellIndex) async {
    final current = state.asData?.value;
    if (current == null) return;
    final next = _engine.moveTableauToFreeCell(current, fromCol, cellIndex);
    if (!identical(next, current)) _usedFreeCells = true;
    applyMove(current, next);
  }

  Future<void> moveFreeCellToTableau(int cellIndex, int toCol) async {
    final current = state.asData?.value;
    if (current == null) return;
    final next = _engine.moveFreeCellToTableau(current, cellIndex, toCol);
    applyMove(current, next);
  }

  Future<void> moveTableauToFoundation(int fromCol) async {
    final current = state.asData?.value;
    if (current == null) return;
    final next = _engine.moveTableauToFoundation(current, fromCol);
    applyMove(current, next);
  }

  Future<void> moveFreeCellToFoundation(int cellIndex) async {
    final current = state.asData?.value;
    if (current == null) return;
    final next = _engine.moveFreeCellToFoundation(current, cellIndex);
    applyMove(current, next);
  }

  Future<void> autoMoveTableauTop(int fromCol) async {
    final current = state.asData?.value;
    if (current == null) return;
    final next = _engine.autoMoveTableauTop(current, fromCol);
    applyMove(current, next);
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
    applyMove(current, next);
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

  @override
  void onMoveApplied(FreecellState previous, FreecellState next) {
    if (!previous.isWin && next.isWin) {
      ref.read(soundServiceProvider).play(SoundEvent.win);
      final day = _dailySessionYmd;
      unawaited(ref.read(statsProvider.notifier).recordGameWin(
        SolitaireVariant.freecell,
        moves: next.moves,
        elapsedSeconds: elapsedSeconds,
        usedUndo: usedUndo,
        usedFreeCells: _usedFreeCells,
        dailyChallenge: day != null,
      ));
      if (day != null) {
        unawaited(_finishDailyWin(day, next.moves, elapsedSeconds));
      }
    }
  }

  @override
  Future<void> saveState(FreecellState value) {
    // Победа — партия закончена: сейв не храним.
    return value.isWin ? _clearSavedGame() : persist(value);
  }

  Future<void> _clearSavedGame() =>
      ref.read(localStoreProvider).clearSavedFreecell();

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

  @override
  Future<void> persist(FreecellState value) async {
    await ref.read(localStoreProvider).saveFreecellState(
          FreecellPersistence.toMap(
            value,
            undoBudget: undoBudgetRemaining,
            dailyYmd: _dailySessionYmd,
          ),
        );
  }
}
