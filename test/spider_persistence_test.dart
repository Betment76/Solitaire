import 'package:flutter_test/flutter_test.dart';
import 'package:solitaire/core/models/card.dart';
import 'package:solitaire/features/spider/domain/spider_persistence.dart';
import 'package:solitaire/features/spider/domain/spider_state.dart';

void main() {
  test('сериализация и восстановление состояния Паука работает', () {
    final source = SpiderState(
      moves: 5,
      completedSequences: 1,
      completedSuits: const [CardSuit.spades],
      stock: const [PlayingCard(suit: CardSuit.hearts, rank: 10, faceUp: true)],
      tableau: List.generate(
        10,
        (i) => i == 0
            ? const [PlayingCard(suit: CardSuit.clubs, rank: 13, faceUp: true)]
            : const <PlayingCard>[],
      ),
    );

    final map = SpiderPersistence.toMap(source, undoBudget: 2, freeHintsRemaining: 1);
    final restored = SpiderPersistence.fromMap(map);

    expect(restored, isNotNull);
    expect(restored!.undoBudget, 2);
    expect(restored.freeHintsRemaining, 1);
    expect(restored.state.moves, 5);
    expect(restored.state.completedSequences, 1);
    expect(restored.state.tableau.length, 10);
    expect(restored.state.tableau[0].length, 1);
  });
}
