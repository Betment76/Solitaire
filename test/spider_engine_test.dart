import 'package:flutter_test/flutter_test.dart';
import 'package:solitaire/features/spider/domain/spider_engine.dart';
import 'package:solitaire/features/spider/domain/spider_state.dart';
import 'package:solitaire/features/klondike/domain/card.dart';

void main() {
  group('SpiderEngine', () {
    final engine = SpiderEngine();

    test('стартовая раздача содержит 104 карты', () {
      final state = engine.newGame(seed: 10);
      final tableauCount =
          state.tableau.fold<int>(0, (sum, pile) => sum + pile.length);
      final total =
          tableauCount + state.stock.length + state.completedSequences * 13;
      expect(total, 104);
      expect(state.tableau[0].length, 6);
      expect(state.tableau[9].length, 5);
      expect(state.stock.length, 50);
    });

    test('колода содержит 4 масти по 2 копии каждой', () {
      final state = engine.newGame(seed: 42, suitCount: 4);
      final allCards = [
        for (final pile in state.tableau) ...pile,
        ...state.stock,
      ];
      expect(allCards.length, 104);
      for (final suit in CardSuit.values) {
        final cardsOfSuit = allCards.where((c) => c.suit == suit).toList();
        expect(cardsOfSuit.length, 26); // 2 copies * 13 ranks
      }
    });

    test('колода содержит 2 масти по 4 копии каждой', () {
      final state = engine.newGame(seed: 42, suitCount: 2);
      final allCards = [
        for (final pile in state.tableau) ...pile,
        ...state.stock,
      ];
      expect(allCards.length, 104);
      for (final suit in CardSuit.values) {
        final cardsOfSuit = allCards.where((c) => c.suit == suit).toList();
        if (suit == CardSuit.hearts || suit == CardSuit.spades) {
          expect(cardsOfSuit.length, 52); // 4 copies * 13 ranks
        } else {
          expect(cardsOfSuit.length, 0);
        }
      }
    });

    test('колода содержит 1 масть по 8 копий каждой', () {
      final state = engine.newGame(seed: 42, suitCount: 1);
      final allCards = [
        for (final pile in state.tableau) ...pile,
        ...state.stock,
      ];
      expect(allCards.length, 104);
      for (final suit in CardSuit.values) {
        final cardsOfSuit = allCards.where((c) => c.suit == suit).toList();
        if (suit == CardSuit.spades) {
          expect(cardsOfSuit.length, 104); // 8 copies * 13 ranks
        } else {
          expect(cardsOfSuit.length, 0);
        }
      }
    });

    test('раздача из стока добавляет по карте в каждую колонку', () {
      final state = engine.newGame(seed: 11);
      final next = engine.dealFromStock(state);
      expect(next.stock.length, 40);
      expect(next.tableau[0].length, state.tableau[0].length + 1);
      expect(next.tableau[9].length, state.tableau[9].length + 1);
    });

    test('перенос валидной стопки работает', () {
      final state = SpiderState(
        stock: const [],
        completedSequences: 0,
        moves: 0,
        tableau: [
          const [
            PlayingCard(suit: CardSuit.spades, rank: 8, faceUp: true),
            PlayingCard(suit: CardSuit.spades, rank: 7, faceUp: true),
          ],
          const [PlayingCard(suit: CardSuit.spades, rank: 9, faceUp: true)],
          [],
          [],
          [],
          [],
          [],
          [],
          [],
          [],
        ],
      );

      final next = engine.moveRun(state, 0, 0, 1);
      expect(next.tableau[0], isEmpty);
      expect(next.tableau[1].length, 3);
      expect(next.tableau[1][1].rank, 8);
      expect(next.tableau[1][2].rank, 7);
    });

    test('перенос стопки другой масти отклоняется', () {
      final state = SpiderState(
        stock: const [],
        completedSequences: 0,
        moves: 0,
        tableau: [
          const [
            PlayingCard(suit: CardSuit.hearts, rank: 8, faceUp: true),
            PlayingCard(suit: CardSuit.spades, rank: 7, faceUp: true),
          ],
          const [PlayingCard(suit: CardSuit.spades, rank: 9, faceUp: true)],
          [],
          [],
          [],
          [],
          [],
          [],
          [],
          [],
        ],
      );

      final next = engine.moveRun(state, 0, 0, 1);
      expect(identical(next, state), isTrue);
    });

    test('canDragRun возвращает false для разномастной стопки', () {
      final state = SpiderState(
        stock: const [],
        completedSequences: 0,
        moves: 0,
        tableau: [
          const [
            PlayingCard(suit: CardSuit.hearts, rank: 8, faceUp: true),
            PlayingCard(suit: CardSuit.spades, rank: 7, faceUp: true),
          ],
          [],
          [],
          [],
          [],
          [],
          [],
          [],
          [],
          [],
        ],
      );

      expect(engine.canDragRun(state, 0, 0), isFalse);
    });

    test('готовая последовательность K..A удаляется (любая масть)', () {
      for (final suit in CardSuit.values) {
        final seq = List.generate(
          13,
          (i) => PlayingCard(suit: suit, rank: 13 - i, faceUp: true),
        );
        final state = SpiderState(
          stock: const [],
          completedSequences: 0,
          moves: 0,
          tableau: [
            seq,
            const [PlayingCard(suit: CardSuit.spades, rank: 9, faceUp: true)],
            [],
            [],
            [],
            [],
            [],
            [],
            [],
            [],
          ],
        );

        final next = engine.moveRun(state, 1, 0, 2);
        expect(next.completedSequences, 1);
        expect(next.tableau[0], isEmpty);
      }
    });

    test('разномастная последовательность K..A не удаляется', () {
      final seq = <PlayingCard>[];
      for (var i = 0; i < 13; i++) {
        seq.add(PlayingCard(
          suit: i < 7 ? CardSuit.spades : CardSuit.hearts,
          rank: 13 - i,
          faceUp: true,
        ));
      }
      final state = SpiderState(
        stock: const [],
        completedSequences: 0,
        moves: 0,
        tableau: [
          seq,
          [],
          [],
          [],
          [],
          [],
          [],
          [],
          [],
          [],
        ],
      );

      final next = engine.moveRun(state, 0, 0, 1);
      expect(next.completedSequences, 0);
    });

    test('hint возвращает перенос при наличии хода', () {
      const filler =
          PlayingCard(suit: CardSuit.hearts, rank: 5, faceUp: true);
      final state = SpiderState(
        stock: List.generate(
          50,
          (i) =>
              PlayingCard(suit: CardSuit.clubs, rank: (i % 13) + 1, faceUp: false),
        ),
        tableau: [
          const [
            PlayingCard(suit: CardSuit.spades, rank: 10, faceUp: true),
          ],
          const [
            PlayingCard(suit: CardSuit.spades, rank: 11, faceUp: true),
          ],
          for (var i = 0; i < 8; i++) [filler],
        ],
      );
      expect(engine.hint(state), 'spider_move_0_0_to_1');
    });
  });
}
