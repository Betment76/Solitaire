import 'package:flutter_test/flutter_test.dart';
import 'package:solitaire/features/klondike/domain/card.dart';
import 'package:solitaire/features/klondike/domain/klondike_engine.dart';
import 'package:solitaire/features/klondike/domain/klondike_state.dart';

void main() {
  group('KlondikeEngine', () {
    final engine = KlondikeEngine();

    test('создает корректную стартовую раздачу на 52 карты', () {
      final state = engine.newGame(drawCount: 1, seed: 42);
      final tableauCount = state.tableau.fold<int>(0, (sum, pile) => sum + pile.length);
      final foundationCount = state.foundations.values.fold<int>(0, (sum, pile) => sum + pile.length);
      final total = tableauCount + state.stock.length + state.waste.length + foundationCount;
      expect(total, 52);
      expect(state.tableau[0].length, 1);
      expect(state.tableau[6].length, 7);
      expect(state.tableau[6].last.faceUp, isTrue);
    });

    test('draw-3 берет 3 карты в waste', () {
      final state = engine.newGame(drawCount: 3, seed: 1);
      final next = engine.draw(state);
      expect(next.waste.length, 3);
      expect(next.stock.length, state.stock.length - 3);
    });

    test('переворот waste в stock при пустом stock работает', () {
      var state = engine.newGame(drawCount: 3, seed: 2);
      while (state.stock.isNotEmpty) {
        state = engine.draw(state);
      }
      final wasteSize = state.waste.length;
      final recycled = engine.draw(state);
      expect(recycled.stock.length, wasteSize);
      expect(recycled.waste, isEmpty);
    });

    test('hint предлагает перекладку табло до добора из колоды', () {
      // 8♠ можно положить на 9♦ (чередование цвета, ранг −1).
      final state = KlondikeState(
        stock: List.generate(
          20,
          (i) => PlayingCard(suit: CardSuit.clubs, rank: (i % 13) + 1, faceUp: false),
        ),
        waste: const [],
        drawCount: 1,
        foundations: {
          CardSuit.hearts: const [],
          CardSuit.diamonds: const [],
          CardSuit.clubs: const [],
          CardSuit.spades: const [],
        },
        tableau: [
          const [PlayingCard(suit: CardSuit.spades, rank: 8, faceUp: true)],
          const [PlayingCard(suit: CardSuit.diamonds, rank: 9, faceUp: true)],
          ...List.generate(5, (_) => const <PlayingCard>[]),
        ],
      );
      expect(engine.hint(state), 'tableau_run_0_0_to_1');
    });

    test('hint предлагает draw, когда нет явного хода из waste', () {
      // Явная позиция: колода не пуста, waste пуст, с вершин колонок нельзя в foundation
      // и нельзя по чередованию цвета — только добор из stock.
      final state = KlondikeState(
        stock: const [PlayingCard(suit: CardSuit.clubs, rank: 3, faceUp: false)],
        waste: const [],
        drawCount: 1,
        foundations: {
          CardSuit.hearts: const [],
          CardSuit.diamonds: const [],
          CardSuit.clubs: const [],
          CardSuit.spades: const [],
        },
        tableau: List.generate(
          7,
          (_) => const [PlayingCard(suit: CardSuit.hearts, rank: 10, faceUp: true)],
        ),
      );
      expect(engine.hint(state), 'draw_from_stock');
    });

    test('победа определяется по 13 картам в каждом foundation', () {
      final state = engine.newGame(drawCount: 1, seed: 7);
      final winning = state.copyWith(
        foundations: {
          CardSuit.hearts: List.generate(13, (i) => PlayingCard(suit: CardSuit.hearts, rank: i + 1)),
          CardSuit.diamonds: List.generate(13, (i) => PlayingCard(suit: CardSuit.diamonds, rank: i + 1)),
          CardSuit.clubs: List.generate(13, (i) => PlayingCard(suit: CardSuit.clubs, rank: i + 1)),
          CardSuit.spades: List.generate(13, (i) => PlayingCard(suit: CardSuit.spades, rank: i + 1)),
        },
      );
      expect(winning.isWin, isTrue);
    });

    test('tap-to-move из tableau в foundation открывает следующую карту', () {
      final state = KlondikeState(
        stock: const [],
        waste: const [],
        drawCount: 1,
        moves: 0,
        foundations: {
          CardSuit.hearts: [const PlayingCard(suit: CardSuit.hearts, rank: 1, faceUp: true)],
          CardSuit.diamonds: const [],
          CardSuit.clubs: const [],
          CardSuit.spades: const [],
        },
        tableau: [
          [
            const PlayingCard(suit: CardSuit.clubs, rank: 9, faceUp: false),
            const PlayingCard(suit: CardSuit.hearts, rank: 2, faceUp: true),
          ],
          const [],
          const [],
          const [],
          const [],
          const [],
          const [],
        ],
      );

      final next = engine.autoMoveTableauTop(state, 0);
      expect(next.foundations[CardSuit.hearts]!.length, 2);
      expect(next.tableau[0].length, 1);
      expect(next.tableau[0].last.faceUp, isTrue);
    });

    test('tap-to-move из waste приоритизирует foundation', () {
      final state = KlondikeState(
        stock: const [],
        waste: const [PlayingCard(suit: CardSuit.spades, rank: 1, faceUp: true)],
        drawCount: 1,
        moves: 0,
        foundations: {
          CardSuit.hearts: const [],
          CardSuit.diamonds: const [],
          CardSuit.clubs: const [],
          CardSuit.spades: const [],
        },
        tableau: List.generate(7, (_) => <PlayingCard>[]),
      );

      final next = engine.autoMoveWaste(state);
      expect(next.waste, isEmpty);
      expect(next.foundations[CardSuit.spades]!.length, 1);
    });

    test('автозавершение переносит карты в foundation при выполненных условиях', () {
      final state = KlondikeState(
        stock: const [],
        waste: const [PlayingCard(suit: CardSuit.hearts, rank: 1, faceUp: true)],
        drawCount: 1,
        moves: 0,
        foundations: {
          CardSuit.hearts: const [],
          CardSuit.diamonds: const [],
          CardSuit.clubs: const [],
          CardSuit.spades: const [],
        },
        tableau: [
          const [PlayingCard(suit: CardSuit.hearts, rank: 2, faceUp: true)],
          const [],
          const [],
          const [],
          const [],
          const [],
          const [],
        ],
      );

      expect(engine.canAutoFinish(state), isTrue);
      final finished = engine.autoFinishAll(state);
      expect(finished.foundations[CardSuit.hearts]!.length, 2);
      expect(finished.waste, isEmpty);
      expect(finished.tableau[0], isEmpty);
    });

    test('переносит стопку открытых карт между колонками', () {
      final state = KlondikeState(
        stock: const [],
        waste: const [],
        drawCount: 1,
        moves: 0,
        foundations: {
          CardSuit.hearts: const [],
          CardSuit.diamonds: const [],
          CardSuit.clubs: const [],
          CardSuit.spades: const [],
        },
        tableau: [
          const [
            PlayingCard(suit: CardSuit.hearts, rank: 6, faceUp: true),
            PlayingCard(suit: CardSuit.clubs, rank: 5, faceUp: true),
          ],
          const [PlayingCard(suit: CardSuit.spades, rank: 7, faceUp: true)],
          const [],
          const [],
          const [],
          const [],
          const [],
        ],
      );

      final next = engine.moveTableauRunToTableau(state, 0, 0, 1);
      expect(next.tableau[0], isEmpty);
      expect(next.tableau[1].length, 3);
      expect(next.tableau[1][1].rank, 6);
      expect(next.tableau[1][2].rank, 5);
    });

    test('не дает перетаскивать невалидную стопку', () {
      final state = KlondikeState(
        stock: const [],
        waste: const [],
        drawCount: 1,
        moves: 0,
        foundations: {
          CardSuit.hearts: const [],
          CardSuit.diamonds: const [],
          CardSuit.clubs: const [],
          CardSuit.spades: const [],
        },
        tableau: [
          const [
            PlayingCard(suit: CardSuit.hearts, rank: 6, faceUp: true),
            PlayingCard(suit: CardSuit.diamonds, rank: 5, faceUp: true), // одинаковый цвет, невалидно
          ],
          const [],
          const [],
          const [],
          const [],
          const [],
          const [],
        ],
      );

      expect(engine.canDragTableauRun(state, 0, 0), isFalse);
      expect(engine.canDragTableauRun(state, 0, 1), isTrue);
    });

    test('разрешает перенос из foundation обратно в tableau', () {
      final state = KlondikeState(
        stock: const [],
        waste: const [],
        drawCount: 1,
        moves: 0,
        foundations: {
          CardSuit.hearts: const [PlayingCard(suit: CardSuit.hearts, rank: 2, faceUp: true)],
          CardSuit.diamonds: const [],
          CardSuit.clubs: const [],
          CardSuit.spades: const [],
        },
        tableau: [
          const [PlayingCard(suit: CardSuit.clubs, rank: 3, faceUp: true)],
          const [],
          const [],
          const [],
          const [],
          const [],
          const [],
        ],
      );

      final next = engine.moveFoundationToTableau(state, CardSuit.hearts, 0);
      expect(next.foundations[CardSuit.hearts], isEmpty);
      expect(next.tableau[0].last.rank, 2);
      expect(next.tableau[0].length, 2);
    });

  });
}
