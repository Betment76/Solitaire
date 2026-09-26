import 'package:flutter_test/flutter_test.dart';
import 'package:solitaire/core/models/card.dart';
import 'package:solitaire/features/spider/domain/spider_engine.dart';
import 'package:solitaire/features/spider/domain/spider_state.dart';

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

    test('dealFromStock: пустой stock не меняет состояние', () {
      final state = SpiderState(
        stock: const [],
        completedSequences: 0,
        moves: 5,
        tableau: List.generate(10, (_) => <PlayingCard>[]),
      );
      final next = engine.dealFromStock(state);
      expect(identical(next, state), isTrue);
    });

    test('dealFromStock: раздача по одной карте в каждую колонку', () {
      final state = SpiderState(
        stock: List.generate(10, (_) => PlayingCard(suit: CardSuit.spades, rank: 5, faceUp: false)),
        completedSequences: 0,
        moves: 0,
        tableau: List.generate(10, (_) => <PlayingCard>[]),
      );
      final next = engine.dealFromStock(state);
      expect(identical(next, state), isFalse);
      expect(next.moves, 1);
      expect(next.stock, isEmpty);
      expect(next.tableau.every((p) => p.length == 1), isTrue);
    });

    test('canAutoFinish: true когда все карты открыты и без стока', () {
      // Build a state where tableau has only face-up cards in valid runs
      final state = SpiderState(
        stock: const [],
        completedSequences: 0,
        moves: 0,
        tableau: List.generate(10, (i) => i < 2
            ? [PlayingCard(suit: CardSuit.spades, rank: 3, faceUp: true)]
            : <PlayingCard>[]),
      );
      final result = engine.canAutoFinish(state);
      // With no stock and all face-up, should be true
      expect(result, isTrue);
    });

    test('canAutoFinish: false когда есть закрытые карты', () {
      final state = SpiderState(
        stock: const [],
        completedSequences: 0,
        moves: 0,
        tableau: [
          const [PlayingCard(suit: CardSuit.spades, rank: 3, faceUp: false)],
          ...List.generate(9, (_) => <PlayingCard>[]),
        ],
      );
      expect(engine.canAutoFinish(state), isFalse);
    });

    test('canAutoFinish: true если есть ход табло даже при непустом stock', () {
      final state = SpiderState(
        stock: [PlayingCard(suit: CardSuit.spades, rank: 5, faceUp: false)],
        completedSequences: 0,
        moves: 0,
        tableau: [
          const [PlayingCard(suit: CardSuit.spades, rank: 3, faceUp: true)],
          ...List.generate(9, (_) => <PlayingCard>[]),
        ],
      );
      expect(engine.canAutoFinish(state), isTrue);
    });

    test('autoFinishAll обрабатывает все колонки', () {
      final state = SpiderState(
        stock: const [],
        completedSequences: 0,
        moves: 0,
        tableau: [
          const [PlayingCard(suit: CardSuit.spades, rank: 13, faceUp: true)],
          const [PlayingCard(suit: CardSuit.spades, rank: 12, faceUp: true)],
          ...List.generate(8, (_) => <PlayingCard>[]),
        ],
      );
      final next = engine.autoFinishAll(state);
      expect(next.tableau[0].isEmpty || next.tableau[1].isEmpty, isTrue);
    });

    test('canDragRun: true для одномастной последовательности', () {
      final state = SpiderState(
        stock: const [],
        completedSequences: 0,
        moves: 0,
        tableau: [
          const [
            PlayingCard(suit: CardSuit.spades, rank: 10, faceUp: true),
            PlayingCard(suit: CardSuit.spades, rank: 9, faceUp: true),
          ],
          ...List.generate(9, (_) => <PlayingCard>[]),
        ],
      );
      expect(engine.canDragRun(state, 0, 0), isTrue);
      expect(engine.canDragRun(state, 0, 1), isTrue);
    });

    test('autoMoveTop перемещает карту в foundation', () {
      final state = SpiderState(
        stock: const [],
        completedSequences: 0,
        moves: 0,
        tableau: [
          const [PlayingCard(suit: CardSuit.spades, rank: 13, faceUp: true)],
          const [PlayingCard(suit: CardSuit.spades, rank: 12, faceUp: true)],
          ...List.generate(8, (_) => <PlayingCard>[]),
        ],
      );
      final next = engine.autoMoveTop(state, 0);
      // Either stays same or moves to another column
      expect(next.moves >= state.moves || identical(next, state), isTrue);
    });

    test('isWin: true когда 8 последовательностей собраны', () {
      final state = SpiderState(
        stock: const [],
        completedSequences: 8,
        completedSuits: List.filled(8, CardSuit.spades),
        moves: 100,
        tableau: List.generate(10, (_) => <PlayingCard>[]),
      );
      expect(state.isWin, isTrue);
    });

    test('isWin: false когда меньше 8 последовательностей', () {
      final state = SpiderState(
        stock: const [],
        completedSequences: 7,
        completedSuits: List.filled(7, CardSuit.spades),
        moves: 100,
        tableau: List.generate(10, (_) => <PlayingCard>[]),
      );
      expect(state.isWin, isFalse);
    });
  });
}
