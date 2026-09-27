import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Общая сессионная логика карточных контроллеров: undo/redo стеки,
/// бюджет бесплатных отмен (добор через rewarded) и применение ходов.
///
/// Контроллер реализует [persist] (запись состояния в LocalStore) и может
/// переопределить [saveState] (например, победа партию не сохраняет) и
/// [onMoveApplied] (звук победы, статистика, испытания).
mixin GameSessionController<S> on AsyncNotifier<S> {
  final List<S> _undoStack = <S>[];
  final List<S> _redoStack = <S>[];

  /// Бесплатные отмены за партию (5), добор — через rewarded.
  int _undoBudget = 5;

  /// Использовался ли Undo хоть раз за текущую партию.
  bool _usedUndo = false;

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
  bool get canUndoWithBudget => canUndo && _undoBudget > 0;
  int get undoBudgetRemaining => _undoBudget;
  bool get usedUndo => _usedUndo;

  /// Сброс сессии в начале новой партии.
  void resetSession() {
    _undoStack.clear();
    _redoStack.clear();
    _undoBudget = 5;
    _usedUndo = false;
  }

  /// Восстановление сессии из сейва (бюджет отмен сохранён, Undo не использован).
  void restoreSession({required int undoBudget}) {
    _undoBudget = undoBudget.clamp(0, 999);
    _usedUndo = false;
  }

  /// Запись состояния в LocalStore (реализует контроллер).
  Future<void> persist(S value);

  /// Финальная запись состояния после хода: по умолчанию [persist].
  /// Контроллер может переопределить (победа партию не сохраняет).
  Future<void> saveState(S value) => persist(value);

  /// Хук после фактического применения хода (победа, звук, статистика).
  void onMoveApplied(S previous, S next) {}

  /// Применяет ход: undo-стек, сброс redo, сохранение.
  void applyMove(S current, S next) {
    if (identical(next, current)) return;
    onMoveApplied(current, next);
    _undoStack.add(current);
    _redoStack.clear();
    state = AsyncData(next);
    unawaited(saveState(next));
  }

  Future<void> undo() async {
    final current = state.asData?.value;
    if (current == null || _undoStack.isEmpty || _undoBudget <= 0) return;
    _undoBudget--;
    _usedUndo = true;
    final previous = _undoStack.removeLast();
    _redoStack.add(current);
    state = AsyncData(previous);
    await persist(previous);
  }

  Future<void> redo() async {
    final current = state.asData?.value;
    if (current == null || _redoStack.isEmpty) return;
    final next = _redoStack.removeLast();
    _undoStack.add(current);
    state = AsyncData(next);
    await persist(next);
  }

  /// +1 бесплатная отмена после rewarded-рекламы.
  void grantUndoFromReward() => _undoBudget++;
}
