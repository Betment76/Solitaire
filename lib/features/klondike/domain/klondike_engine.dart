import 'dart:math';

import 'card.dart';
import 'klondike_state.dart';

/// Движок правил Косынки (MVP): draw, ходы из waste, подсказка.
class KlondikeEngine {
  KlondikeState newGame({required int drawCount, int? seed}) {
    final deck = _buildDeck(seed: seed);
    final tableau = List.generate(7, (_) => <PlayingCard>[]);

    // Раздаем 7 колонок: в каждой верхняя карта открыта.
    var index = 0;
    for (var col = 0; col < 7; col++) {
      for (var row = 0; row <= col; row++) {
        final isFaceUp = row == col;
        tableau[col].add(deck[index].copyWith(faceUp: isFaceUp));
        index++;
      }
    }

    final stock = deck.sublist(index).map((c) => c.copyWith(faceUp: false)).toList();
    final foundations = {
      CardSuit.hearts: <PlayingCard>[],
      CardSuit.diamonds: <PlayingCard>[],
      CardSuit.clubs: <PlayingCard>[],
      CardSuit.spades: <PlayingCard>[],
    };

    return KlondikeState(
      stock: stock,
      waste: const [],
      foundations: foundations,
      tableau: tableau,
      drawCount: drawCount,
    );
  }

  KlondikeState draw(KlondikeState state) {
    if (state.stock.isEmpty) {
      // Переворот waste обратно в stock при пустом стоке.
      return state.copyWith(
        stock: state.waste.reversed.map((c) => c.copyWith(faceUp: false)).toList(),
        waste: const [],
        moves: state.moves + 1,
      );
    }

    final nextStock = [...state.stock];
    final nextWaste = [...state.waste];
    final count = min(state.drawCount, nextStock.length);

    for (var i = 0; i < count; i++) {
      final card = nextStock.removeLast();
      nextWaste.add(card.copyWith(faceUp: true));
    }

    return state.copyWith(stock: nextStock, waste: nextWaste, moves: state.moves + 1);
  }

  KlondikeState moveWasteToFoundation(KlondikeState state) {
    if (state.waste.isEmpty) return state;
    final card = state.waste.last;
    final target = state.foundations[card.suit]!;
    if (!_canMoveToFoundation(card, target)) return state;

    final nextWaste = [...state.waste]..removeLast();
    final nextFoundations = _cloneFoundations(state.foundations);
    nextFoundations[card.suit]!.add(card);

    return state.copyWith(
      waste: nextWaste,
      foundations: nextFoundations,
      moves: state.moves + 1,
    );
  }

  KlondikeState moveWasteToTableau(KlondikeState state, int tableauIndex) {
    if (state.waste.isEmpty) return state;
    final card = state.waste.last;

    final nextTableau = _cloneTableau(state.tableau);
    final targetPile = nextTableau[tableauIndex];
    final targetTop = targetPile.isEmpty ? null : targetPile.last;

    if (!_canPlaceOnTableau(card, targetTop)) return state;

    final nextWaste = [...state.waste]..removeLast();
    targetPile.add(card);

    return state.copyWith(
      waste: nextWaste,
      tableau: nextTableau,
      moves: state.moves + 1,
    );
  }

  /// Возврат верхней карты из foundation обратно в tableau.
  KlondikeState moveFoundationToTableau(KlondikeState state, CardSuit suit, int tableauIndex) {
    final foundationPile = state.foundations[suit]!;
    if (foundationPile.isEmpty) return state;
    final moving = foundationPile.last;

    final nextTableau = _cloneTableau(state.tableau);
    final targetPile = nextTableau[tableauIndex];
    final targetTop = targetPile.isEmpty ? null : targetPile.last;
    if (!_canPlaceOnTableau(moving, targetTop)) return state;

    final nextFoundations = _cloneFoundations(state.foundations);
    nextFoundations[suit]!.removeLast();
    targetPile.add(moving);

    return state.copyWith(
      foundations: nextFoundations,
      tableau: nextTableau,
      moves: state.moves + 1,
    );
  }

  /// Tap-to-move для waste: сначала foundation, затем tableau.
  KlondikeState autoMoveWaste(KlondikeState state) {
    final toFoundation = moveWasteToFoundation(state);
    if (toFoundation != state) return toFoundation;
    for (var i = 0; i < state.tableau.length; i++) {
      final moved = moveWasteToTableau(state, i);
      if (moved != state) return moved;
    }
    return state;
  }

  /// Перемещение верхней карты из колонки в foundation.
  KlondikeState moveTableauTopToFoundation(KlondikeState state, int fromIndex) {
    final fromPile = state.tableau[fromIndex];
    if (fromPile.isEmpty) return state;
    final card = fromPile.last;
    if (!card.faceUp) return state;

    final foundationTarget = state.foundations[card.suit]!;
    if (!_canMoveToFoundation(card, foundationTarget)) return state;

    final nextTableau = _cloneTableau(state.tableau);
    nextTableau[fromIndex].removeLast();
    _flipTopIfNeeded(nextTableau[fromIndex]);

    final nextFoundations = _cloneFoundations(state.foundations);
    nextFoundations[card.suit]!.add(card);

    return state.copyWith(
      tableau: nextTableau,
      foundations: nextFoundations,
      moves: state.moves + 1,
    );
  }

  /// Перемещение верхней карты из одной колонки в другую.
  KlondikeState moveTableauTopToTableau(KlondikeState state, int fromIndex, int toIndex) {
    if (fromIndex == toIndex) return state;
    final fromPile = state.tableau[fromIndex];
    if (fromPile.isEmpty) return state;
    final moving = fromPile.last;
    if (!moving.faceUp) return state;

    final targetPile = state.tableau[toIndex];
    final targetTop = targetPile.isEmpty ? null : targetPile.last;
    if (!_canPlaceOnTableau(moving, targetTop)) return state;

    final nextTableau = _cloneTableau(state.tableau);
    nextTableau[fromIndex].removeLast();
    _flipTopIfNeeded(nextTableau[fromIndex]);
    nextTableau[toIndex].add(moving);

    return state.copyWith(tableau: nextTableau, moves: state.moves + 1);
  }

  /// Перемещение последовательности открытых карт из колонки в колонку.
  KlondikeState moveTableauRunToTableau(
    KlondikeState state,
    int fromColumn,
    int fromCardIndex,
    int toColumn,
  ) {
    if (fromColumn == toColumn) return state;
    final fromPile = state.tableau[fromColumn];
    if (fromCardIndex < 0 || fromCardIndex >= fromPile.length) return state;

    final run = fromPile.sublist(fromCardIndex);
    if (run.isEmpty || !_isValidRun(run)) return state;

    final targetPile = state.tableau[toColumn];
    final targetTop = targetPile.isEmpty ? null : targetPile.last;
    if (!_canPlaceOnTableau(run.first, targetTop)) return state;

    final nextTableau = _cloneTableau(state.tableau);
    nextTableau[fromColumn].removeRange(fromCardIndex, nextTableau[fromColumn].length);
    _flipTopIfNeeded(nextTableau[fromColumn]);
    nextTableau[toColumn].addAll(run);

    return state.copyWith(tableau: nextTableau, moves: state.moves + 1);
  }

  /// Можно ли начать перетаскивание стопки с указанной карты.
  bool canDragTableauRun(KlondikeState state, int fromColumn, int fromCardIndex) {
    final fromPile = state.tableau[fromColumn];
    if (fromCardIndex < 0 || fromCardIndex >= fromPile.length) return false;
    final run = fromPile.sublist(fromCardIndex);
    return run.isNotEmpty && _isValidRun(run);
  }

  /// Tap-to-move для колонки: приоритет foundation, затем любая валидная колонка.
  KlondikeState autoMoveTableauTop(KlondikeState state, int fromIndex) {
    final toFoundation = moveTableauTopToFoundation(state, fromIndex);
    if (toFoundation != state) return toFoundation;
    for (var to = 0; to < state.tableau.length; to++) {
      final moved = moveTableauTopToTableau(state, fromIndex, to);
      if (moved != state) return moved;
    }
    return state;
  }

  /// Проверяем, можно ли безопасно запускать автозавершение.
  bool canAutoFinish(KlondikeState state) {
    final hasFaceDown = state.tableau.any((pile) => pile.any((card) => !card.faceUp));
    return !hasFaceDown && state.stock.isEmpty;
  }

  /// Один шаг автозавершения: сначала waste, затем верхние карты колонок.
  KlondikeState autoFinishStep(KlondikeState state) {
    final fromWaste = moveWasteToFoundation(state);
    if (!identical(fromWaste, state)) return fromWaste;
    for (var i = 0; i < state.tableau.length; i++) {
      final moved = moveTableauTopToFoundation(state, i);
      if (!identical(moved, state)) return moved;
    }
    return state;
  }

  /// Автозавершение партии до первого тупика.
  KlondikeState autoFinishAll(KlondikeState state) {
    if (!canAutoFinish(state)) return state;
    var current = state;
    while (true) {
      final next = autoFinishStep(current);
      if (identical(next, current)) break;
      current = next;
    }
    return current;
  }

  String? hint(KlondikeState state) {
    if (state.waste.isNotEmpty) {
      final card = state.waste.last;
      final foundation = state.foundations[card.suit]!;
      if (_canMoveToFoundation(card, foundation)) {
        return 'waste_to_foundation';
      }
      for (var i = 0; i < state.tableau.length; i++) {
        final pile = state.tableau[i];
        final top = pile.isEmpty ? null : pile.last;
        if (_canPlaceOnTableau(card, top)) {
          return 'waste_to_tableau_$i';
        }
      }
    }
    // Проверяем ходы из колонок в foundation (даже если stock не пуст).
    for (var i = 0; i < state.tableau.length; i++) {
      final pile = state.tableau[i];
      if (pile.isEmpty) continue;
      final top = pile.last;
      if (!top.faceUp) continue;
      final foundation = state.foundations[top.suit]!;
      if (_canMoveToFoundation(top, foundation)) {
        return 'tableau_to_foundation_$i';
      }
    }
    // Табло → табло (одна карта или стопка), раньше чем добор из колоды.
    for (var from = 0; from < state.tableau.length; from++) {
      final pile = state.tableau[from];
      for (var idx = pile.length - 1; idx >= 0; idx--) {
        if (!pile[idx].faceUp) break;
        if (!canDragTableauRun(state, from, idx)) continue;
        for (var to = 0; to < state.tableau.length; to++) {
          if (to == from) continue;
          final moved = moveTableauRunToTableau(state, from, idx, to);
          if (!identical(moved, state)) {
            return 'tableau_run_${from}_${idx}_to_$to';
          }
        }
      }
    }
    if (state.stock.isNotEmpty) return 'draw_from_stock';
    return null;
  }

  bool _canMoveToFoundation(PlayingCard card, List<PlayingCard> target) {
    if (target.isEmpty) return card.rank == 1;
    final top = target.last;
    return top.suit == card.suit && card.rank == top.rank + 1;
  }

  bool _canPlaceOnTableau(PlayingCard moving, PlayingCard? targetTop) {
    if (targetTop == null) return moving.rank == 13;
    return moving.color != targetTop.color && moving.rank == targetTop.rank - 1;
  }

  /// Проверка, что переносимая последовательность корректна по правилам Косынки.
  bool _isValidRun(List<PlayingCard> run) {
    if (run.any((card) => !card.faceUp)) return false;
    for (var i = 0; i < run.length - 1; i++) {
      final upper = run[i];
      final lower = run[i + 1];
      if (upper.color == lower.color) return false;
      if (upper.rank != lower.rank + 1) return false;
    }
    return true;
  }

  Map<CardSuit, List<PlayingCard>> _cloneFoundations(Map<CardSuit, List<PlayingCard>> value) {
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

  /// После снятия верхней карты автоматически открываем новую верхнюю.
  void _flipTopIfNeeded(List<PlayingCard> pile) {
    if (pile.isEmpty) return;
    final top = pile.last;
    if (!top.faceUp) {
      pile[pile.length - 1] = top.copyWith(faceUp: true);
    }
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
