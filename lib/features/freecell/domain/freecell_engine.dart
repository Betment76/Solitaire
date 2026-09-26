import 'dart:math';

import '../../../core/models/card.dart';
import 'freecell_state.dart';

/// Подсказка FreeCell: машинный тип хода (перевод и подсветка — на экране).
sealed class FreecellHint {
  const FreecellHint();
}

/// Верхняя карта колонки [col] → дом.
class HintFcTableauToFoundation extends FreecellHint {
  const HintFcTableauToFoundation(this.col);
  final int col;

  @override
  bool operator ==(Object other) =>
      other is HintFcTableauToFoundation && other.col == col;

  @override
  int get hashCode => Object.hash(HintFcTableauToFoundation, col);
}

/// Карта из ячейки [cell] → дом.
class HintFcCellToFoundation extends FreecellHint {
  const HintFcCellToFoundation(this.cell);
  final int cell;

  @override
  bool operator ==(Object other) =>
      other is HintFcCellToFoundation && other.cell == cell;

  @override
  int get hashCode => Object.hash(HintFcCellToFoundation, cell);
}

/// Верхняя карта колонки [from] → колонка [to].
class HintFcTableauToTableau extends FreecellHint {
  const HintFcTableauToTableau(this.from, this.to);
  final int from;
  final int to;

  @override
  bool operator ==(Object other) =>
      other is HintFcTableauToTableau &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(HintFcTableauToTableau, from, to);
}

/// Верхняя карта колонки [col] → свободная ячейка [cell].
class HintFcTableauToCell extends FreecellHint {
  const HintFcTableauToCell(this.col, this.cell);
  final int col;
  final int cell;

  @override
  bool operator ==(Object other) =>
      other is HintFcTableauToCell &&
      other.col == col &&
      other.cell == cell;

  @override
  int get hashCode => Object.hash(HintFcTableauToCell, col, cell);
}

/// Движок правил FreeCell (MVP).
class FreecellEngine {
  FreecellState newGame({int? seed}) {
    final deck = _buildDeck(seed: seed);
    final tableau = List.generate(8, (_) => <PlayingCard>[]);

    for (var i = 0; i < deck.length; i++) {
      tableau[i % 8].add(deck[i].copyWith(faceUp: true));
    }

    return FreecellState(
      tableau: tableau,
      freeCells: List<PlayingCard?>.filled(4, null),
      extraFreeCellSlots: 0,
      freeExtraCellUnlockPending: true,
      foundations: {
        CardSuit.hearts: <PlayingCard>[],
        CardSuit.diamonds: <PlayingCard>[],
        CardSuit.clubs: <PlayingCard>[],
        CardSuit.spades: <PlayingCard>[],
      },
    );
  }

  /// Максимум карт, которые можно перенести за один ход по правилам FreeCell.
  /// Учитываем только "временные" пустые колонки:
  /// - исходную [fromCol] и целевую [toCol] не считаем.
  /// Формула: (1 + emptyFreeCells) * 2^(emptyTempColumns).
  int _maxMovableCardsForMove(
    FreecellState state, {
    required int fromCol,
    required int toCol,
  }) {
    final emptyFreeCells = state.freeCells.where((c) => c == null).length;
    var emptyTempColumns = 0;
    for (var i = 0; i < state.tableau.length; i++) {
      if (i == fromCol || i == toCol) continue;
      if (state.tableau[i].isEmpty) emptyTempColumns++;
    }
    return (1 + emptyFreeCells) * (1 << emptyTempColumns);
  }

  /// Длина валидной последовательности от низа колонки (чередование цвета, убывание ранга).
  int _runLength(List<PlayingCard> pile) {
    if (pile.isEmpty) return 0;
    int len = 1;
    for (var i = pile.length - 1; i > 0; i--) {
      final cur = pile[i];
      final prev = pile[i - 1];
      if (cur.color == prev.color || cur.rank != prev.rank - 1) break;
      len++;
    }
    return len;
  }

  /// Перемещает карту(ы) из [fromCol] в [toCol].
  /// Если [fromCardIndex] задан — тащит последовательность от этого индекса.
  /// Иначе — от низа колонки (максимум по правилам FreeCell).
  FreecellState moveTableauToTableau(
    FreecellState state,
    int fromCol,
    int toCol, {
    int? fromCardIndex,
  }) {
    if (fromCol == toCol) return state;
    final fromPile = state.tableau[fromCol];
    if (fromPile.isEmpty) return state;

    if (fromCardIndex != null && fromCardIndex < fromPile.length) {
      // Явный индекс — тащим оттуда.
      return _moveRun(state, fromCol, fromCardIndex, toCol);
    }

    // Авто-выбор: от низа колонки, сколько позволяет _maxMovableCards.
    final runLen = _runLength(fromPile);
    final maxCards = _maxMovableCardsForMove(
      state,
      fromCol: fromCol,
      toCol: toCol,
    );
    final moveCount = runLen.clamp(1, maxCards);
    final startIdx = fromPile.length - moveCount;
    if (moveCount == 1) {
      return _moveSingleTableauToTableau(state, fromCol, toCol);
    }
    final run = fromPile.sublist(startIdx);
    for (var i = 0; i < run.length - 1; i++) {
      if (run[i].color == run[i + 1].color || run[i].rank != run[i + 1].rank + 1) return state;
    }
    final movingFirst = run.first;
    final toPile = state.tableau[toCol];
    final target = toPile.isEmpty ? null : toPile.last;
    if (!_canPlaceOnTableau(movingFirst, target)) return state;

    final nextTableau = _cloneTableau(state.tableau);
    nextTableau[fromCol].removeRange(startIdx, nextTableau[fromCol].length);
    nextTableau[toCol].addAll(run);
    return state.copyWith(tableau: nextTableau, moves: state.moves + 1);
  }

  /// Перемещает последовательность от [fromIndex] до конца колонки.
  FreecellState _moveRun(
    FreecellState state,
    int fromCol,
    int fromIndex,
    int toCol,
  ) {
    final fromPile = state.tableau[fromCol];
    final run = fromPile.sublist(fromIndex);
    // Валидация последовательности.
    for (var i = 0; i < run.length - 1; i++) {
      if (run[i].color == run[i + 1].color || run[i].rank != run[i + 1].rank + 1) return state;
    }
    final toPile = state.tableau[toCol];
    final target = toPile.isEmpty ? null : toPile.last;
    if (!_canPlaceOnTableau(run.first, target)) return state;
    if (
      run.length >
          _maxMovableCardsForMove(state, fromCol: fromCol, toCol: toCol)
    ) {
      return state;
    }

    final nextTableau = _cloneTableau(state.tableau);
    nextTableau[fromCol].removeRange(fromIndex, nextTableau[fromCol].length);
    nextTableau[toCol].addAll(run);
    return state.copyWith(tableau: nextTableau, moves: state.moves + 1);
  }

  /// Перемещение только верхней карты (drag / авто-ходы).
  FreecellState _moveSingleTableauToTableau(
    FreecellState state,
    int fromCol,
    int toCol,
  ) {
    if (fromCol == toCol) return state;
    final fromPile = state.tableau[fromCol];
    if (fromPile.isEmpty) return state;

    final moving = fromPile.last;
    final toPile = state.tableau[toCol];
    final target = toPile.isEmpty ? null : toPile.last;
    if (!_canPlaceOnTableau(moving, target)) return state;

    final nextTableau = _cloneTableau(state.tableau);
    nextTableau[fromCol].removeLast();
    nextTableau[toCol].add(moving);
    return state.copyWith(tableau: nextTableau, moves: state.moves + 1);
  }

  FreecellState moveTableauToFreeCell(
    FreecellState state,
    int fromCol,
    int cellIndex,
  ) {
    final fromPile = state.tableau[fromCol];
    if (fromPile.isEmpty) return state;
    if (cellIndex < 0 || cellIndex >= state.freeCells.length) return state;
    if (state.freeCells[cellIndex] != null) return state;

    final nextTableau = _cloneTableau(state.tableau);
    final moving = nextTableau[fromCol].removeLast();
    final nextCells = [...state.freeCells];
    nextCells[cellIndex] = moving;

    return state.copyWith(
      tableau: nextTableau,
      freeCells: nextCells,
      moves: state.moves + 1,
    );
  }

  FreecellState moveFreeCellToTableau(
    FreecellState state,
    int cellIndex,
    int toCol,
  ) {
    if (cellIndex < 0 || cellIndex >= state.freeCells.length) return state;
    final moving = state.freeCells[cellIndex];
    if (moving == null) return state;

    final toPile = state.tableau[toCol];
    final target = toPile.isEmpty ? null : toPile.last;
    if (!_canPlaceOnTableau(moving, target)) return state;

    final nextCells = [...state.freeCells];
    nextCells[cellIndex] = null;
    final nextTableau = _cloneTableau(state.tableau);
    nextTableau[toCol].add(moving);

    return state.copyWith(
      tableau: nextTableau,
      freeCells: nextCells,
      moves: state.moves + 1,
    );
  }

  FreecellState moveTableauToFoundation(FreecellState state, int fromCol) {
    final fromPile = state.tableau[fromCol];
    if (fromPile.isEmpty) return state;
    final moving = fromPile.last;
    if (!_canMoveToFoundation(moving, state.foundations[moving.suit]!)) {
      return state;
    }

    final nextTableau = _cloneTableau(state.tableau);
    nextTableau[fromCol].removeLast();
    final nextFoundations = _cloneFoundations(state.foundations);
    nextFoundations[moving.suit]!.add(moving);

    return state.copyWith(
      tableau: nextTableau,
      foundations: nextFoundations,
      moves: state.moves + 1,
    );
  }

  FreecellState moveFreeCellToFoundation(FreecellState state, int cellIndex) {
    if (cellIndex < 0 || cellIndex >= state.freeCells.length) return state;
    final moving = state.freeCells[cellIndex];
    if (moving == null) return state;
    if (!_canMoveToFoundation(moving, state.foundations[moving.suit]!)) {
      return state;
    }

    final nextCells = [...state.freeCells];
    nextCells[cellIndex] = null;
    final nextFoundations = _cloneFoundations(state.foundations);
    nextFoundations[moving.suit]!.add(moving);

    return state.copyWith(
      freeCells: nextCells,
      foundations: nextFoundations,
      moves: state.moves + 1,
    );
  }

  FreecellState autoMoveTableauTop(FreecellState state, int fromCol) {
    final toFoundation = moveTableauToFoundation(state, fromCol);
    if (!identical(toFoundation, state)) return toFoundation;

    for (var c = 0; c < state.tableau.length; c++) {
      final moved = moveTableauToTableau(state, fromCol, c);
      if (!identical(moved, state)) return moved;
    }

    for (var i = 0; i < state.freeCells.length; i++) {
      final moved = moveTableauToFreeCell(state, fromCol, i);
      if (!identical(moved, state)) return moved;
    }

    return state;
  }

  /// Возвращает список колонок табло, куда можно положить карту из [fromCol].
  List<int> getLegalTableauTargets(FreecellState state, int fromCol) {
    final pile = state.tableau[fromCol];
    if (pile.isEmpty) return [];
    final top = pile.last;
    final targets = <int>[];
    for (var to = 0; to < state.tableau.length; to++) {
      if (to == fromCol) continue;
      final toPile = state.tableau[to];
      final target = toPile.isEmpty ? null : toPile.last;
      if (_canPlaceOnTableau(top, target)) {
        targets.add(to);
      }
    }
    return targets;
  }

  /// Возвращает список free cell индексов, которые пусты (можно положить карту).
  List<int> getEmptyFreeCells(FreecellState state) {
    final cells = <int>[];
    for (var i = 0; i < state.freeCells.length; i++) {
      if (state.freeCells[i] == null) cells.add(i);
    }
    return cells;
  }

  /// Подсказка: машинный тип хода или null. Приоритет: foundation > tableau > ячейка.
  FreecellHint? hint(FreecellState state) {
    if (state.isWin) return null;
    // 1. Ход в foundation: из колонок, затем из ячеек.
    for (var c = 0; c < state.tableau.length; c++) {
      final pile = state.tableau[c];
      if (pile.isEmpty) continue;
      if (_canMoveToFoundation(pile.last, state.foundations[pile.last.suit]!)) {
        return HintFcTableauToFoundation(c);
      }
    }
    for (var i = 0; i < state.freeCells.length; i++) {
      final card = state.freeCells[i];
      if (card == null) continue;
      if (_canMoveToFoundation(card, state.foundations[card.suit]!)) {
        return HintFcCellToFoundation(i);
      }
    }
    // 2. Ход на tableau: ищем карту, которую можно куда-то положить.
    for (var c = 0; c < state.tableau.length; c++) {
      final pile = state.tableau[c];
      if (pile.isEmpty) continue;
      final targets = getLegalTableauTargets(state, c);
      if (targets.isNotEmpty) {
        return HintFcTableauToTableau(c, targets.first);
      }
    }
    // 3. Запасная свободная ячейка.
    final emptyCells = getEmptyFreeCells(state);
    if (emptyCells.isNotEmpty) {
      for (var c = 0; c < state.tableau.length; c++) {
        if (state.tableau[c].isNotEmpty) {
          return HintFcTableauToCell(c, emptyCells.first);
        }
      }
    }
    return null;
  }

  /// Проверяет, есть ли хотя бы один ход в foundation.
  bool canAutoFinish(FreecellState state) {
    if (state.isWin) return false;
    for (var c = 0; c < state.tableau.length; c++) {
      final pile = state.tableau[c];
      if (pile.isEmpty) continue;
      if (_canMoveToFoundation(pile.last, state.foundations[pile.last.suit]!)) {
        return true;
      }
    }
    for (var i = 0; i < state.freeCells.length; i++) {
      final card = state.freeCells[i];
      if (card == null) continue;
      if (_canMoveToFoundation(card, state.foundations[card.suit]!)) {
        return true;
      }
    }
    return false;
  }

  /// Один шаг автозавершения: верх колонок → foundation, потом freeCell → foundation.
  FreecellState autoFinishStep(FreecellState state) {
    for (var c = 0; c < state.tableau.length; c++) {
      final moved = moveTableauToFoundation(state, c);
      if (!identical(moved, state)) return moved;
    }
    for (var i = 0; i < state.freeCells.length; i++) {
      final moved = moveFreeCellToFoundation(state, i);
      if (!identical(moved, state)) return moved;
    }
    return state;
  }

  /// Повторяет шаг, пока есть ходы.
  FreecellState autoFinishAll(FreecellState state) {
    if (!canAutoFinish(state)) return state;
    var current = state;
    while (true) {
      final next = autoFinishStep(current);
      if (identical(next, current)) break;
      current = next;
    }
    return current;
  }

  bool _canPlaceOnTableau(PlayingCard moving, PlayingCard? target) {
    if (target == null) return true;
    return moving.color != target.color && moving.rank == target.rank - 1;
  }

  bool _canMoveToFoundation(PlayingCard moving, List<PlayingCard> pile) {
    if (pile.isEmpty) return moving.rank == 1;
    final top = pile.last;
    return moving.suit == top.suit && moving.rank == top.rank + 1;
  }

  Map<CardSuit, List<PlayingCard>> _cloneFoundations(
    Map<CardSuit, List<PlayingCard>> value,
  ) {
    return {
      CardSuit.hearts: [...value[CardSuit.hearts]!],
      CardSuit.diamonds: [...value[CardSuit.diamonds]!],
      CardSuit.clubs: [...value[CardSuit.clubs]!],
      CardSuit.spades: [...value[CardSuit.spades]!],
    };
  }

  List<List<PlayingCard>> _cloneTableau(List<List<PlayingCard>> value) {
    return value.map((pile) => [...pile]).toList();
  }

  List<PlayingCard> _buildDeck({int? seed}) {
    final deck = <PlayingCard>[];
    for (final suit in CardSuit.values) {
      for (var rank = 1; rank <= 13; rank++) {
        deck.add(PlayingCard(suit: suit, rank: rank));
      }
    }
    deck.shuffle(Random(seed));
    return deck;
  }
}
