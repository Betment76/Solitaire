import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics/app_analytics.dart';
import '../../core/audio/sound_service.dart';
import '../../core/daily_seed.dart';
import '../../core/models/app_stats.dart';
import '../../core/providers.dart';
import 'domain/card.dart';
import 'domain/klondike_engine.dart';
import 'domain/klondike_persistence.dart';
import 'domain/klondike_state.dart';

final klondikeControllerProvider =
    AsyncNotifierProvider<KlondikeController, KlondikeState>(KlondikeController.new);

/// Контроллер состояния Косынки: новая игра, ходы, undo/redo, сохранение.
class KlondikeController extends AsyncNotifier<KlondikeState> {
  final KlondikeEngine _engine = KlondikeEngine();
  final List<KlondikeState> _undo = <KlondikeState>[];
  final List<KlondikeState> _redo = <KlondikeState>[];
  int _drawCount = 1;
  /// Дата `YYYY-MM-DD` активной ежедневной партии (для рекорда по ходам).
  String? _dailySessionYmd;

  /// Лимиты «бесплатно за партию»; добор через rewarded — см. grant*FromReward.
  int _freeHintsRemaining = 3;
  int _freeAutoFinishRemaining = 1;
  /// Вторая попытка ежедневного челленджа за рекламу (один раз за сессию дня).
  bool _dailyRewardRetryUsed = false;

  bool get isDailySession => _dailySessionYmd != null;
  bool get canOfferDailyRetryAd {
    final cur = state.asData?.value;
    if (_dailySessionYmd == null || cur == null || cur.isWin) return false;
    if (cur.moves <= 0) return false;
    return !_dailyRewardRetryUsed;
  }

  bool get canUseFreeHint => _freeHintsRemaining > 0;
  /// Оставшиеся бесплатные подсказки (добор через рекламу увеличивает счётчик).
  int get freeHintsRemaining => _freeHintsRemaining;
  bool get canUseFreeAutoFinish => _freeAutoFinishRemaining > 0;

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  int get drawCount => _drawCount;

  int _drawCountFromSettings() {
    final v = ref.read(settingsProvider).asData?.value.klondikeDrawCount ?? 1;
    return v == 3 ? 3 : 1;
  }

  static String _todayYmd() => DateTime.now().toIso8601String().substring(0, 10);

  @override
  Future<KlondikeState> build() async {
    final saved = await ref.read(localStoreProvider).loadKlondikeState();
    final restored = KlondikePersistence.fromMap(saved);
    _undo.clear();
    _redo.clear();
    if (restored != null) {
      _drawCount = restored.state.drawCount;
      _dailySessionYmd = restored.dailyYmd;
      _freeHintsRemaining = restored.freeHintsRemaining;
      _freeAutoFinishRemaining = restored.freeAutoFinishRemaining;
      _dailyRewardRetryUsed = restored.dailyRewardRetryUsed;
      return restored.state;
    }
    _freeHintsRemaining = 3;
    _freeAutoFinishRemaining = 1;
    _dailyRewardRetryUsed = false;
    _drawCount = _drawCountFromSettings();
    return _engine.newGame(drawCount: _drawCount, seed: DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> newGame({int? drawCount}) async {
    _dailySessionYmd = null;
    _freeHintsRemaining = 3;
    _freeAutoFinishRemaining = 1;
    _dailyRewardRetryUsed = false;
    final cur = state.asData?.value;
    if (cur != null && !cur.isWin) {
      unawaited(ref.read(statsProvider.notifier).recordGameAbandoned());
    }
    final dc = drawCount ?? _drawCountFromSettings();
    _drawCount = dc == 3 ? 3 : 1;
    final next = _engine.newGame(drawCount: _drawCount, seed: DateTime.now().millisecondsSinceEpoch);
    _undo.clear();
    _redo.clear();
    state = AsyncData(next);
    await _persist(next);
    unawaited(reportGameStart(SolitaireVariant.klondike));
  }

  /// Ежедневная раздача: фиксированный seed от сегодняшней даты (ТЗ п.15).
  Future<void> startDailyChallenge() async {
    final cur = state.asData?.value;
    if (cur != null && !cur.isWin) {
      unawaited(ref.read(statsProvider.notifier).recordGameAbandoned());
    }
    _dailySessionYmd = _todayYmd();
    _freeHintsRemaining = 3;
    _freeAutoFinishRemaining = 1;
    _dailyRewardRetryUsed = false;
    _drawCount = _drawCountFromSettings();
    final seed = klondikeDailySeed(_dailySessionYmd!);
    final next = _engine.newGame(drawCount: _drawCount, seed: seed);
    _undo.clear();
    _redo.clear();
    state = AsyncData(next);
    await _persist(next);
    unawaited(reportGameStart(SolitaireVariant.klondike, dailyChallenge: true));
  }

  /// Вторая попытка той же ежедневной раздачи после rewarded.
  Future<void> restartDailyAfterRewardAd() async {
    if (_dailySessionYmd == null) return;
    final cur = state.asData?.value;
    if (cur != null && !cur.isWin) {
      unawaited(ref.read(statsProvider.notifier).recordGameAbandoned());
    }
    _freeHintsRemaining = 3;
    _freeAutoFinishRemaining = 1;
    _dailyRewardRetryUsed = true;
    _drawCount = _drawCountFromSettings();
    final seed = klondikeDailySeed(_dailySessionYmd!);
    final next = _engine.newGame(drawCount: _drawCount, seed: seed);
    _undo.clear();
    _redo.clear();
    state = AsyncData(next);
    await _persist(next);
    unawaited(reportGameStart(SolitaireVariant.klondike, dailyChallenge: true));
  }

  void grantHintFromReward() => _freeHintsRemaining++;

  void grantAutoFinishFromReward() => _freeAutoFinishRemaining++;

  /// Подсказка: бесплатные попытки или нужна реклама (`needsReward`).
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

  Future<void> draw() async {
    final current = state.asData?.value;
    if (current == null) return;
    final next = _engine.draw(current);
    _apply(current, next);
  }

  Future<void> autoMoveWaste() async {
    final current = state.asData?.value;
    if (current == null) return;
    final next = _engine.autoMoveWaste(current);
    _apply(current, next);
  }

  Future<void> autoMoveTableauTop(int columnIndex) async {
    final current = state.asData?.value;
    if (current == null) return;
    final next = _engine.autoMoveTableauTop(current, columnIndex);
    _apply(current, next);
  }

  Future<void> moveWasteToTableau(int tableauIndex) async {
    final current = state.asData?.value;
    if (current == null) return;
    final next = _engine.moveWasteToTableau(current, tableauIndex);
    _apply(current, next);
  }

  Future<void> moveWasteToFoundation() async {
    final current = state.asData?.value;
    if (current == null) return;
    final next = _engine.moveWasteToFoundation(current);
    _apply(current, next);
  }

  Future<void> moveTableauTopToFoundation(int fromIndex) async {
    final current = state.asData?.value;
    if (current == null) return;
    final next = _engine.moveTableauTopToFoundation(current, fromIndex);
    _apply(current, next);
  }

  Future<void> moveTableauTopToTableau(int fromIndex, int toIndex) async {
    final current = state.asData?.value;
    if (current == null) return;
    final next = _engine.moveTableauTopToTableau(current, fromIndex, toIndex);
    _apply(current, next);
  }

  Future<void> moveTableauRunToTableau(int fromColumn, int fromCardIndex, int toColumn) async {
    final current = state.asData?.value;
    if (current == null) return;
    final next = _engine.moveTableauRunToTableau(current, fromColumn, fromCardIndex, toColumn);
    _apply(current, next);
  }

  Future<void> moveFoundationToTableau(CardSuit suit, int tableauIndex) async {
    final current = state.asData?.value;
    if (current == null) return;
    final next = _engine.moveFoundationToTableau(current, suit, tableauIndex);
    _apply(current, next);
  }

  Future<void> autoFinishStep() async {
    final current = state.asData?.value;
    if (current == null) return;
    final next = _engine.autoFinishStep(current);
    _apply(current, next);
  }

  Future<void> autoFinishAll() async {
    final current = state.asData?.value;
    if (current == null) return;
    if (!_engine.canAutoFinish(current)) return;
    if (_freeAutoFinishRemaining <= 0) return;
    final next = _engine.autoFinishAll(current);
    _freeAutoFinishRemaining--;
    _apply(current, next);
  }

  bool canDragTableauRun(int fromColumn, int fromCardIndex) {
    final current = state.asData?.value;
    if (current == null) return false;
    return _engine.canDragTableauRun(current, fromColumn, fromCardIndex);
  }

  bool canAutoFinish() {
    final current = state.asData?.value;
    if (current == null) return false;
    return _engine.canAutoFinish(current) && _freeAutoFinishRemaining > 0;
  }

  /// Движок допускает автодобор (без учёта лимита rewarded).
  bool engineAllowsAutoFinish() {
    final current = state.asData?.value;
    if (current == null) return false;
    return _engine.canAutoFinish(current);
  }

  String? hint() {
    final current = state.asData?.value;
    if (current == null) return null;
    return _engine.hint(current);
  }

  /// Сохраняем прошедшее время без влияния на undo/redo.
  Future<void> saveElapsedSeconds(int seconds) async {
    final current = state.asData?.value;
    if (current == null) return;
    final normalized = seconds < 0 ? 0 : seconds;
    if (normalized == current.elapsedSeconds) return;
    final next = current.copyWith(elapsedSeconds: normalized);
    state = AsyncData(next);
    await _persist(next);
  }

  void _apply(KlondikeState current, KlondikeState next) {
    if (identical(next, current)) return;
    _maybeRecordWin(current, next);
    _undo.add(current);
    _redo.clear();
    state = AsyncData(next);
    unawaited(_persist(next));
  }

  Future<void> _persist(KlondikeState value) async {
    await ref.read(localStoreProvider).saveKlondikeState(
          KlondikePersistence.toMap(
            value,
            dailyYmd: _dailySessionYmd,
            freeHintsRemaining: _freeHintsRemaining,
            freeAutoFinishRemaining: _freeAutoFinishRemaining,
            dailyRewardRetryUsed: _dailyRewardRetryUsed,
          ),
        );
  }

  /// Метод для применения хода из экрана (когда уже есть preview).
  void applyFromScreen(KlondikeState current, KlondikeState next) {
    if (identical(next, current)) return;
    _maybeRecordWin(current, next);
    _undo.add(current);
    _redo.clear();
    state = AsyncData(next);
    unawaited(_persist(next));
  }

  void _maybeRecordWin(KlondikeState current, KlondikeState next) {
    if (current.isWin || !next.isWin) return;
    ref.read(soundServiceProvider).play(SoundEvent.win);
    final score = next.foundations.values.fold<int>(0, (a, b) => a + b.length) * 10;
    final day = _dailySessionYmd;
    unawaited(
      ref.read(statsProvider.notifier).recordGameWin(
            SolitaireVariant.klondike,
            klondikeScore: score,
            dailyChallenge: day != null,
          ),
    );
    if (day != null) {
      unawaited(_finishDailyWin(day, next.moves));
    }
  }

  /// Рекорд дня + уведомление для UI и обновление провайдера лучшего результата.
  Future<void> _finishDailyWin(String day, int moves) async {
    final improved = await ref.read(localStoreProvider).saveDailyKlondikeBestMovesIfBetter(day, moves);
    ref.read(dailyWinFlashProvider.notifier).show(DailyWinFlash(moves: moves, newBestForDay: improved));
    ref.invalidate(dailyKlondikeBestMovesProvider(day));
  }
}
