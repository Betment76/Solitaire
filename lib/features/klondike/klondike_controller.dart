import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics/app_analytics.dart';
import '../../core/controllers/game_session_controller.dart';
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
class KlondikeController extends AsyncNotifier<KlondikeState>
    with GameSessionController<KlondikeState> {
  final KlondikeEngine _engine = KlondikeEngine();
  int _drawCount = 1;
  /// Дата `YYYY-MM-DD` активной ежедневной партии (для рекорда по ходам).
  String? _dailySessionYmd;

  /// Лимиты «бесплатно за партию»; добор подсказок через rewarded — см. grantHintFromReward.
  int _freeHintsRemaining = 3;
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
    resetSession();
    // Победённую партию не восстанавливаем (лечит и старые сейвы-победы):
    // «продолжать» нечего — начинаем новую.
    if (restored != null && !restored.state.isWin) {
      _drawCount = restored.state.drawCount;
      _dailySessionYmd = restored.dailyYmd;
      _freeHintsRemaining = restored.freeHintsRemaining;
      _dailyRewardRetryUsed = restored.dailyRewardRetryUsed;
      restoreSession(undoBudget: restored.undoBudget);
      return restored.state;
    }
    _freeHintsRemaining = 3;
    _dailyRewardRetryUsed = false;
    _drawCount = _drawCountFromSettings();
    return _engine.newGame(drawCount: _drawCount, seed: DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> newGame({int? drawCount}) async {
    _dailySessionYmd = null;
    _freeHintsRemaining = 3;
    _dailyRewardRetryUsed = false;
    resetSession();
    final cur = state.asData?.value;
    if (cur != null && !cur.isWin) {
      unawaited(ref.read(statsProvider.notifier).recordGameAbandoned());
    }
    final dc = drawCount ?? _drawCountFromSettings();
    _drawCount = dc == 3 ? 3 : 1;
    final next = _engine.newGame(drawCount: _drawCount, seed: DateTime.now().millisecondsSinceEpoch);
    state = AsyncData(next);
    await persist(next);
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
    _dailyRewardRetryUsed = false;
    resetSession();
    _drawCount = _drawCountFromSettings();
    final seed = klondikeDailySeed(_dailySessionYmd!);
    final next = _engine.newGame(drawCount: _drawCount, seed: seed);
    state = AsyncData(next);
    await persist(next);
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
    _dailyRewardRetryUsed = true;
    resetSession();
    _drawCount = _drawCountFromSettings();
    final seed = klondikeDailySeed(_dailySessionYmd!);
    final next = _engine.newGame(drawCount: _drawCount, seed: seed);
    state = AsyncData(next);
    await persist(next);
    unawaited(reportGameStart(SolitaireVariant.klondike, dailyChallenge: true));
  }

  void grantHintFromReward() => _freeHintsRemaining++;

  /// Подсказка: бесплатные попытки или нужна реклама (`needsReward`).
  ({KlondikeHint? hint, bool needsReward, bool noMoves}) takeHintOrPrepareReward() {
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

  Future<void> draw() async {
    final current = state.asData?.value;
    if (current == null) return;
    final next = _engine.draw(current);
    applyMove(current, next);
  }

  Future<void> autoMoveWaste() async {
    final current = state.asData?.value;
    if (current == null) return;
    final next = _engine.autoMoveWaste(current);
    applyMove(current, next);
  }

  Future<void> autoMoveTableauTop(int columnIndex) async {
    final current = state.asData?.value;
    if (current == null) return;
    final next = _engine.autoMoveTableauTop(current, columnIndex);
    applyMove(current, next);
  }

  Future<void> moveWasteToTableau(int tableauIndex) async {
    final current = state.asData?.value;
    if (current == null) return;
    final next = _engine.moveWasteToTableau(current, tableauIndex);
    applyMove(current, next);
  }

  Future<void> moveWasteToFoundation() async {
    final current = state.asData?.value;
    if (current == null) return;
    final next = _engine.moveWasteToFoundation(current);
    applyMove(current, next);
  }

  Future<void> moveTableauTopToFoundation(int fromIndex) async {
    final current = state.asData?.value;
    if (current == null) return;
    final next = _engine.moveTableauTopToFoundation(current, fromIndex);
    applyMove(current, next);
  }

  Future<void> moveTableauTopToTableau(int fromIndex, int toIndex) async {
    final current = state.asData?.value;
    if (current == null) return;
    final next = _engine.moveTableauTopToTableau(current, fromIndex, toIndex);
    applyMove(current, next);
  }

  Future<void> moveTableauRunToTableau(int fromColumn, int fromCardIndex, int toColumn) async {
    final current = state.asData?.value;
    if (current == null) return;
    final next = _engine.moveTableauRunToTableau(current, fromColumn, fromCardIndex, toColumn);
    applyMove(current, next);
  }

  Future<void> moveFoundationToTableau(CardSuit suit, int tableauIndex) async {
    final current = state.asData?.value;
    if (current == null) return;
    final next = _engine.moveFoundationToTableau(current, suit, tableauIndex);
    applyMove(current, next);
  }

  Future<void> autoFinishStep() async {
    final current = state.asData?.value;
    if (current == null) return;
    final next = _engine.autoFinishStep(current);
    applyMove(current, next);
  }

  Future<void> autoFinishAll() async {
    final current = state.asData?.value;
    if (current == null) return;
    if (!_engine.canAutoFinish(current)) return;
    final next = _engine.autoFinishAll(current);
    applyMove(current, next);
  }

  bool canDragTableauRun(int fromColumn, int fromCardIndex) {
    final current = state.asData?.value;
    if (current == null) return false;
    return _engine.canDragTableauRun(current, fromColumn, fromCardIndex);
  }

  // --- Проверки ходов для drag-and-drop (без изменения состояния) ---

  bool canMoveWasteToTableau(int tableauIndex) {
    final current = state.asData?.value;
    if (current == null) return false;
    return !identical(_engine.moveWasteToTableau(current, tableauIndex), current);
  }

  bool canMoveWasteToFoundation() {
    final current = state.asData?.value;
    if (current == null) return false;
    return !identical(_engine.moveWasteToFoundation(current), current);
  }

  bool canMoveTableauTopToFoundation(int fromIndex) {
    final current = state.asData?.value;
    if (current == null) return false;
    return !identical(
      _engine.moveTableauTopToFoundation(current, fromIndex),
      current,
    );
  }

  bool canMoveFoundationToTableau(CardSuit suit, int tableauIndex) {
    final current = state.asData?.value;
    if (current == null) return false;
    return !identical(
      _engine.moveFoundationToTableau(current, suit, tableauIndex),
      current,
    );
  }

  bool canMoveTableauRunToTableau(int fromColumn, int fromCardIndex, int toColumn) {
    final current = state.asData?.value;
    if (current == null) return false;
    return !identical(
      _engine.moveTableauRunToTableau(current, fromColumn, fromCardIndex, toColumn),
      current,
    );
  }

  bool canAutoFinish() {
    final current = state.asData?.value;
    if (current == null) return false;
    return _engine.canAutoFinish(current);
  }

  KlondikeHint? hint() {
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
    await persist(next);
  }

  @override
  void onMoveApplied(KlondikeState previous, KlondikeState next) {
    _maybeRecordWin(previous, next);
  }

  @override
  Future<void> saveState(KlondikeState value) {
    // Победа — партия закончена: сейв не храним, чтобы меню не предлагало «Продолжить».
    return value.isWin ? _clearSavedGame() : persist(value);
  }

  Future<void> _clearSavedGame() =>
      ref.read(localStoreProvider).clearSavedKlondike();

  @override
  Future<void> persist(KlondikeState value) async {
    await ref.read(localStoreProvider).saveKlondikeState(
          KlondikePersistence.toMap(
            value,
            dailyYmd: _dailySessionYmd,
            freeHintsRemaining: _freeHintsRemaining,
            dailyRewardRetryUsed: _dailyRewardRetryUsed,
            undoBudget: undoBudgetRemaining,
          ),
        );
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
            moves: next.moves,
            elapsedSeconds: next.elapsedSeconds,
            usedUndo: usedUndo,
          ),
    );
    if (day != null) {
      unawaited(_finishDailyWin(day, next.moves, next.elapsedSeconds));
    }
  }

  /// Рекорд дня + уведомление для UI и обновление провайдера лучшего результата.
  Future<void> _finishDailyWin(String day, int moves, int elapsedSeconds) async {
    final store = ref.read(localStoreProvider);
    final improved = await store.saveDailyKlondikeBestMovesIfBetter(day, moves);
    await store.saveDailyKlondikeBestTimeIfBetter(day, elapsedSeconds);
    ref.read(dailyWinFlashProvider.notifier).show(DailyWinFlash(moves: moves, newBestForDay: improved));
    ref.invalidate(dailyKlondikeBestMovesProvider(day));
    ref.invalidate(dailyKlondikeBestTimeProvider(day));
  }
}
