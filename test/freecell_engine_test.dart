import 'package:flutter_test/flutter_test.dart';
import 'package:solitaire/features/freecell/domain/freecell_engine.dart';
import 'package:solitaire/features/freecell/domain/freecell_state.dart';
import 'package:solitaire/features/klondike/domain/card.dart';

void main() {
  group('FreecellEngine', () {
    final engine = FreecellEngine();

    test('стартовая раздача содержит 52 карты', () {
      final state = engine.newGame(seed: 5);
      final tableauCount = state.tableau.fold<int>(0, (sum, pile) => sum + pile.length);
      final freeCount = state.freeCells.whereType<PlayingCard>().length;
      final foundationCount = state.foundations.values.fold<int>(0, (sum, pile) => sum + pile.length);
      expect(tableauCount + freeCount + foundationCount, 52);
      expect(state.tableau[0].length, 7);
      expect(state.tableau[7].length, 6);
    });

    test('перемещение tableau -> freecell работает', () {
      final state = engine.newGame(seed: 6);
      final before = state.tableau[0].length;
      final next = engine.moveTableauToFreeCell(state, 0, 0);
      expect(next.tableau[0].length, before - 1);
      expect(next.freeCells[0], isNotNull);
    });

    test('перемещение freecell -> foundation работает для туза', () {
      final state = FreecellState(
        tableau: List.generate(8, (_) => <PlayingCard>[]),
        freeCells: const [PlayingCard(suit: CardSuit.spades, rank: 1, faceUp: true), null, null, null],
        foundations: {
          CardSuit.hearts: const [],
          CardSuit.diamonds: const [],
          CardSuit.clubs: const [],
          CardSuit.spades: const [],
        },
      );

      final next = engine.moveFreeCellToFoundation(state, 0);
      expect(next.freeCells[0], isNull);
      expect(next.foundations[CardSuit.spades]!.length, 1);
    });

    test('перемещение tableau -> tableau проверяет правила цвета/ранга', () {
      final state = FreecellState(
        tableau: [
          const [PlayingCard(suit: CardSuit.hearts, rank: 6, faceUp: true)],
          const [PlayingCard(suit: CardSuit.clubs, rank: 7, faceUp: true)],
          const [],
          const [],
          const [],
          const [],
          const [],
          const [],
        ],
        freeCells: const [null, null, null, null],
        foundations: {
          CardSuit.hearts: const [],
          CardSuit.diamonds: const [],
          CardSuit.clubs: const [],
          CardSuit.spades: const [],
        },
      );

      final next = engine.moveTableauToTableau(state, 0, 1);
      expect(next.tableau[0], isEmpty);
      expect(next.tableau[1].length, 2);
    });
  });
}
