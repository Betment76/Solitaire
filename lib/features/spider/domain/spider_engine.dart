import 'dart:math';

import '../../../core/models/card.dart';
import 'spider_state.dart';

/// Движок правил Паука (1/2/4 масти, всего 8 последовательностей).
class SpiderEngine {
  SpiderState newGame({int? seed, int suitCount = 1}) {
    final normalizedSuitCount = suitCount == 2 || suitCount == 4 ? suitCount : 1;
    final deck = _buildDeck(suitCount: normalizedSuitCount, seed: seed);
    final tableau = List.generate(10, (_) => <PlayingCard>[]);

    var index = 0;
    for (var col = 0; col < 10; col++) {
      final count = col < 4 ? 6 : 5;
      for (var row = 0; row < count; row++) {
        final faceUp = row == count - 1;
        tableau[col].add(deck[index].copyWith(faceUp: faceUp));
        index++;
      }
    }

    final stock = deck
        .sublist(index)
        .map((c) => c.copyWith(faceUp: false))
        .toList();
    return SpiderState(stock: stock, tableau: tableau);
  }

  SpiderState dealFromStock(SpiderState state) {
    if (state.stock.length < 10) return state;
    if (state.tableau.any((pile) => pile.isEmpty)) return state;

    final nextStock = [...state.stock];
    final nextTableau = _cloneTableau(state.tableau);
    for (var i = 0; i < 10; i++) {
      final card = nextStock.removeLast().copyWith(faceUp: true);
      nextTableau[i].add(card);
    }

    return _normalizeAndCount(
      state.copyWith(
        stock: nextStock,
        tableau: nextTableau,
        moves: state.moves + 1,
      ),
    );
  }

  SpiderState moveRun(
    SpiderState state,
    int fromColumn,
    int fromIndex,
    int toColumn,
  ) {
    if (fromColumn == toColumn) return state;
    final fromPile = state.tableau[fromColumn];
    if (fromIndex < 0 || fromIndex >= fromPile.length) return state;

    final run = fromPile.sublist(fromIndex);
    if (!_isValidRun(run)) return state;

    final toPile = state.tableau[toColumn];
    final toTop = toPile.isEmpty ? null : toPile.last;
    if (!_canPlace(run.first, toTop)) return state;

    final nextTableau = _cloneTableau(state.tableau);
    nextTableau[fromColumn].removeRange(
      fromIndex,
      nextTableau[fromColumn].length,
    );
    _flipTopIfNeeded(nextTableau[fromColumn]);
    nextTableau[toColumn].addAll(run);

    return _normalizeAndCount(
      state.copyWith(tableau: nextTableau, moves: state.moves + 1),
    );
  }

  bool canDragRun(SpiderState state, int fromColumn, int fromIndex) {
    final fromPile = state.tableau[fromColumn];
    if (fromIndex < 0 || fromIndex >= fromPile.length) return false;
    return _isValidRun(fromPile.sublist(fromIndex));
  }

  SpiderState autoMoveTop(SpiderState state, int fromColumn) {
    final pile = state.tableau[fromColumn];
    if (pile.isEmpty) return state;
    final idx = pile.length - 1;
    for (var to = 0; to < state.tableau.length; to++) {
      final moved = moveRun(state, fromColumn, idx, to);
      if (!identical(moved, state)) return moved;
    }
    return state;
  }

  SpiderState _normalizeAndCount(SpiderState state) {
    final nextTableau = _cloneTableau(state.tableau);
    var completed = state.completedSequences;
    final suits = <CardSuit>[...state.completedSuits];

    for (var col = 0; col < nextTableau.length; col++) {
      while (nextTableau[col].length >= 13) {
        final tail = nextTableau[col].sublist(nextTableau[col].length - 13);
        if (_isCompleteSuitSequence(tail)) {
          suits.add(tail.first.suit);
          nextTableau[col].removeRange(
            nextTableau[col].length - 13,
            nextTableau[col].length,
          );
          _flipTopIfNeeded(nextTableau[col]);
          completed++;
        } else {
          break;
        }
      }
    }

    return state.copyWith(tableau: nextTableau, completedSequences: completed, completedSuits: suits);
  }

  bool _canPlace(PlayingCard movingFirst, PlayingCard? targetTop) {
    if (targetTop == null) return true;
    return movingFirst.rank == targetTop.rank - 1;
  }

  bool _isValidRun(List<PlayingCard> run) {
    if (run.isEmpty) return false;
    if (run.any((c) => !c.faceUp)) return false;
    final suit = run.first.suit;
    for (var i = 0; i < run.length - 1; i++) {
      if (run[i].rank != run[i + 1].rank + 1) return false;
      if (run[i + 1].suit != suit) return false;
    }
    return true;
  }

  bool _isCompleteSuitSequence(List<PlayingCard> cards) {
    if (cards.length != 13) return false;
    if (cards.any((c) => !c.faceUp)) return false;
    final suit = cards.first.suit;
    for (var i = 0; i < 13; i++) {
      final expectedRank = 13 - i;
      if (cards[i].rank != expectedRank) return false;
      if (cards[i].suit != suit) return false;
    }
    return true;
  }

  void _flipTopIfNeeded(List<PlayingCard> pile) {
    if (pile.isEmpty) return;
    final top = pile.last;
    if (!top.faceUp) {
      pile[pile.length - 1] = top.copyWith(faceUp: true);
    }
  }

  List<List<PlayingCard>> _cloneTableau(List<List<PlayingCard>> value) {
    return value.map((pile) => [...pile]).toList();
  }

  /// Первый доступный ход: перенос стопки или сдача из колоды (если разрешена).
  String? hint(SpiderState state) {
    for (var from = 0; from < state.tableau.length; from++) {
      final pile = state.tableau[from];
      for (var idx = pile.length - 1; idx >= 0; idx--) {
        if (!pile[idx].faceUp) break;
        if (!canDragRun(state, from, idx)) continue;
        for (var to = 0; to < state.tableau.length; to++) {
          if (to == from) continue;
          final moved = moveRun(state, from, idx, to);
          if (!identical(moved, state)) {
            return 'spider_move_${from}_${idx}_to_$to';
          }
        }
      }
    }
    final dealt = dealFromStock(state);
    if (!identical(dealt, state)) return 'spider_deal_stock';
    return null;
  }

  List<PlayingCard> _buildDeck({required int suitCount, int? seed}) {
    // Паук всегда разыгрывает 104 карты = 8 последовательностей * 13.
    // Отличие только в том, сколько мастей присутствует в последовательностях.
    // Чтобы общее количество карт осталось 104:
    //  1 масть -> 8 копий каждой карты (rank 1..13)
    //  2 масти -> 4 копии каждой карты
    //  4 масти -> 2 копии каждой карты
    final normalizedSuitCount = suitCount == 2 || suitCount == 4 ? suitCount : 1;

    final selectedSuits = switch (normalizedSuitCount) {
      1 => const [CardSuit.spades],
      2 => const [CardSuit.hearts, CardSuit.spades],
      _ => CardSuit.values,
    };

    final copiesPerSuit = 8 ~/ normalizedSuitCount; // 8, 4 или 2

    final deck = <PlayingCard>[];
    for (final suit in selectedSuits) {
      for (var copy = 0; copy < copiesPerSuit; copy++) {
        for (var rank = 1; rank <= 13; rank++) {
          deck.add(PlayingCard(suit: suit, rank: rank));
        }
      }
    }

    deck.shuffle(Random(seed));
    return deck;
  }
}
