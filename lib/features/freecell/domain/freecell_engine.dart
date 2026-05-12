import 'dart:math';

import '../../../core/models/card.dart';
import 'freecell_state.dart';

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
    if (!_canMoveToFoundation(moving, state.foundations[moving.suit]!))
      return state;

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
    if (!_canMoveToFoundation(moving, state.foundations[moving.suit]!))
      return state;

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
