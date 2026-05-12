import 'package:flutter_test/flutter_test.dart';
import 'package:solitaire/features/freecell/domain/freecell_persistence.dart';
import 'package:solitaire/features/freecell/domain/freecell_state.dart';
import 'package:solitaire/features/klondike/domain/card.dart';

void main() {
  test('сериализация и восстановление состояния FreeCell работает', () {
    final source = FreecellState(
      moves: 9,
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
      freeCells: const [PlayingCard(suit: CardSuit.spades, rank: 1, faceUp: true), null, null, null],
      foundations: {
        CardSuit.hearts: const [],
        CardSuit.diamonds: const [],
        CardSuit.clubs: const [],
        CardSuit.spades: const [PlayingCard(suit: CardSuit.spades, rank: 1, faceUp: true)],
      },
    );

    final map = FreecellPersistence.toMap(source);
    final restored = FreecellPersistence.fromMap(map);

    expect(restored, isNotNull);
    expect(restored!.state.moves, 9);
    expect(restored.state.tableau[0].length, 1);
    expect(restored.state.freeCells[0], isNotNull);
    expect(restored.state.foundations[CardSuit.spades]!.length, 1);
  });
}
