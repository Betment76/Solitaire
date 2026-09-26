import 'package:flutter_test/flutter_test.dart';
import 'package:solitaire/core/models/card.dart';
import 'package:solitaire/features/freecell/domain/freecell_engine.dart';
import 'package:solitaire/features/freecell/domain/freecell_state.dart';

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

    test('все карты открыты при раздаче', () {
      final state = engine.newGame(seed: 42);
      for (final pile in state.tableau) {
        for (final card in pile) {
          expect(card.faceUp, isTrue);
        }
      }
    });

    test('перемещение tableau -> freecell работает', () {
      final state = engine.newGame(seed: 6);
      final before = state.tableau[0].length;
      final next = engine.moveTableauToFreeCell(state, 0, 0);
      expect(next.tableau[0].length, before - 1);
      expect(next.freeCells[0], isNotNull);
      expect(next.moves, state.moves + 1);
    });

    test('перемещение tableau -> freecell на занятую ячейку отклоняется', () {
      final state = FreecellState(
        tableau: [
          const [PlayingCard(suit: CardSuit.hearts, rank: 5, faceUp: true)],
          ...List.generate(7, (_) => <PlayingCard>[]),
        ],
        freeCells: const [PlayingCard(suit: CardSuit.spades, rank: 1, faceUp: true), null, null, null],
        foundations: {for (final s in CardSuit.values) s: <PlayingCard>[]},
      );
      final next = engine.moveTableauToFreeCell(state, 0, 0);
      expect(identical(next, state), isTrue);
    });

    test('перемещение tableau -> freecell с неверным индексом отклоняется', () {
      final state = engine.newGame(seed: 1);
      final next = engine.moveTableauToFreeCell(state, 0, 10);
      expect(identical(next, state), isTrue);
    });

    test('перемещение из пустой колонки tableau -> freecell отклоняется', () {
      final state = FreecellState(
        tableau: List.generate(8, (_) => <PlayingCard>[]),
        freeCells: List.filled(4, null),
        foundations: {for (final s in CardSuit.values) s: <PlayingCard>[]},
      );
      final next = engine.moveTableauToFreeCell(state, 0, 0);
      expect(identical(next, state), isTrue);
    });

    test('перемещение freecell -> foundation работает для туза', () {
      final state = FreecellState(
        tableau: List.generate(8, (_) => <PlayingCard>[]),
        freeCells: const [PlayingCard(suit: CardSuit.spades, rank: 1, faceUp: true), null, null, null],
        foundations: {for (final s in CardSuit.values) s: <PlayingCard>[]},
      );
      final next = engine.moveFreeCellToFoundation(state, 0);
      expect(next.freeCells[0], isNull);
      expect(next.foundations[CardSuit.spades]!.length, 1);
      expect(next.moves, 1);
    });

    test('перемещение freecell -> foundation не-туз без базы отклоняется', () {
      final state = FreecellState(
        tableau: List.generate(8, (_) => <PlayingCard>[]),
        freeCells: const [PlayingCard(suit: CardSuit.hearts, rank: 5, faceUp: true), null, null, null],
        foundations: {for (final s in CardSuit.values) s: <PlayingCard>[]},
      );
      final next = engine.moveFreeCellToFoundation(state, 0);
      expect(identical(next, state), isTrue);
    });

    test('перемещение freecell -> foundation неверный индекс', () {
      final state = engine.newGame(seed: 1);
      final next = engine.moveFreeCellToFoundation(state, 99);
      expect(identical(next, state), isTrue);
    });

    test('перемещение tableau -> tableau проверяет правила цвета/ранга', () {
      final state = FreecellState(
        tableau: [
          const [PlayingCard(suit: CardSuit.hearts, rank: 6, faceUp: true)],
          const [PlayingCard(suit: CardSuit.clubs, rank: 7, faceUp: true)],
          ...List.generate(6, (_) => <PlayingCard>[]),
        ],
        freeCells: List.filled(4, null),
        foundations: {for (final s in CardSuit.values) s: <PlayingCard>[]},
      );
      final next = engine.moveTableauToTableau(state, 0, 1);
      expect(next.tableau[0], isEmpty);
      expect(next.tableau[1].length, 2);
    });

    test('перемещение tableau -> tableau: одинаковый цвет отклоняется', () {
      final state = FreecellState(
        tableau: [
          const [PlayingCard(suit: CardSuit.hearts, rank: 6, faceUp: true)],
          const [PlayingCard(suit: CardSuit.diamonds, rank: 7, faceUp: true)],
          ...List.generate(6, (_) => <PlayingCard>[]),
        ],
        freeCells: List.filled(4, null),
        foundations: {for (final s in CardSuit.values) s: <PlayingCard>[]},
      );
      final next = engine.moveTableauToTableau(state, 0, 1);
      expect(identical(next, state), isTrue);
    });

    test('перемещение tableau -> tableau: неверный ранг отклоняется', () {
      final state = FreecellState(
        tableau: [
          const [PlayingCard(suit: CardSuit.hearts, rank: 4, faceUp: true)],
          const [PlayingCard(suit: CardSuit.clubs, rank: 7, faceUp: true)],
          ...List.generate(6, (_) => <PlayingCard>[]),
        ],
        freeCells: List.filled(4, null),
        foundations: {for (final s in CardSuit.values) s: <PlayingCard>[]},
      );
      final next = engine.moveTableauToTableau(state, 0, 1);
      expect(identical(next, state), isTrue);
    });

    test('перемещение tableau -> tableau: одна колонка', () {
      final state = engine.newGame(seed: 1);
      final next = engine.moveTableauToTableau(state, 0, 0);
      expect(identical(next, state), isTrue);
    });

    test('перемещение таблицы пустая колонка — любая карта', () {
      final state = FreecellState(
        tableau: [
          const [PlayingCard(suit: CardSuit.hearts, rank: 13, faceUp: true)],
          ...List.generate(7, (_) => <PlayingCard>[]),
        ],
        freeCells: List.filled(4, null),
        foundations: {for (final s in CardSuit.values) s: <PlayingCard>[]},
      );
      final next = engine.moveTableauToTableau(state, 0, 1);
      expect(next.tableau[0], isEmpty);
      expect(next.tableau[1].length, 1);
    });

    test('moveFreeCellToTableau: на пустую колонку', () {
      final state = FreecellState(
        tableau: List.generate(8, (_) => <PlayingCard>[]),
        freeCells: const [PlayingCard(suit: CardSuit.spades, rank: 8, faceUp: true), null, null, null],
        foundations: {for (final s in CardSuit.values) s: <PlayingCard>[]},
      );
      final next = engine.moveFreeCellToTableau(state, 0, 3);
      expect(next.freeCells[0], isNull);
      expect(next.tableau[3].length, 1);
    });

    test('moveFreeCellToTableau: с проверкой правил', () {
      final state = FreecellState(
        tableau: [
          const [],
          const [PlayingCard(suit: CardSuit.spades, rank: 9, faceUp: true)],
          ...List.generate(6, (_) => <PlayingCard>[]),
        ],
        freeCells: const [PlayingCard(suit: CardSuit.hearts, rank: 8, faceUp: true), null, null, null],
        foundations: {for (final s in CardSuit.values) s: <PlayingCard>[]},
      );
      final next = engine.moveFreeCellToTableau(state, 0, 1);
      expect(next.freeCells[0], isNull);
      expect(next.tableau[1].length, 2);
    });

    test('moveFreeCellToTableau: неверный цвет отклоняется', () {
      final state = FreecellState(
        tableau: [
          const [],
          const [PlayingCard(suit: CardSuit.spades, rank: 9, faceUp: true)],
          ...List.generate(6, (_) => <PlayingCard>[]),
        ],
        freeCells: const [PlayingCard(suit: CardSuit.clubs, rank: 8, faceUp: true), null, null, null],
        foundations: {for (final s in CardSuit.values) s: <PlayingCard>[]},
      );
      final next = engine.moveFreeCellToTableau(state, 0, 1);
      expect(identical(next, state), isTrue);
    });

    test('moveTableauToFoundation: верхняя карта в foundation', () {
      final state = FreecellState(
        tableau: [
          const [PlayingCard(suit: CardSuit.hearts, rank: 1, faceUp: true), PlayingCard(suit: CardSuit.hearts, rank: 2, faceUp: true)],
          ...List.generate(7, (_) => <PlayingCard>[]),
        ],
        freeCells: List.filled(4, null),
        foundations: {
          CardSuit.hearts: const [PlayingCard(suit: CardSuit.hearts, rank: 1)],
          CardSuit.diamonds: const [],
          CardSuit.clubs: const [],
          CardSuit.spades: const [],
        },
      );
      final next = engine.moveTableauToFoundation(state, 0);
      expect(next.tableau[0].length, 1);
      expect(next.foundations[CardSuit.hearts]!.length, 2);
    });

    test('moveTableauToFoundation: не подходит по масти', () {
      final state = FreecellState(
        tableau: [
          const [PlayingCard(suit: CardSuit.diamonds, rank: 2, faceUp: true)],
          ...List.generate(7, (_) => <PlayingCard>[]),
        ],
        freeCells: List.filled(4, null),
        foundations: {
          CardSuit.hearts: const [PlayingCard(suit: CardSuit.hearts, rank: 1)],
          CardSuit.diamonds: const [],
          CardSuit.clubs: const [],
          CardSuit.spades: const [],
        },
      );
      final next = engine.moveTableauToFoundation(state, 0);
      expect(identical(next, state), isTrue);
    });

    test('canAutoFinish и autoFinishAll', () {
      // Почти полная раздача: осталась одна карта вне foundation
      final foundations = {
        CardSuit.hearts: List.generate(13, (i) => PlayingCard(suit: CardSuit.hearts, rank: i + 1)),
        CardSuit.diamonds: List.generate(13, (i) => PlayingCard(suit: CardSuit.diamonds, rank: i + 1)),
        CardSuit.clubs: List.generate(13, (i) => PlayingCard(suit: CardSuit.clubs, rank: i + 1)),
        CardSuit.spades: List.generate(12, (i) => PlayingCard(suit: CardSuit.spades, rank: i + 1)),
      };
      final state = FreecellState(
        tableau: [
          const [PlayingCard(suit: CardSuit.spades, rank: 13, faceUp: true)],
          ...List.generate(7, (_) => <PlayingCard>[]),
        ],
        freeCells: List.filled(4, null),
        foundations: foundations,
      );
      expect(engine.canAutoFinish(state), isTrue);
      final finished = engine.autoFinishAll(state);
      expect(finished.isWin, isTrue);
    });

    test('canAutoFinish: нет ходов в foundation', () {
      final state = FreecellState(
        tableau: List.generate(8, (_) => <PlayingCard>[]),
        freeCells: const [PlayingCard(suit: CardSuit.hearts, rank: 5, faceUp: true), null, null, null],
        foundations: {for (final s in CardSuit.values) s: <PlayingCard>[]},
      );
      expect(engine.canAutoFinish(state), isFalse);
    });

    test('hint находит ход в foundation', () {
      final state = FreecellState(
        tableau: [
          const [PlayingCard(suit: CardSuit.hearts, rank: 5, faceUp: true)],
          const [PlayingCard(suit: CardSuit.hearts, rank: 1, faceUp: true)],
          ...List.generate(6, (_) => <PlayingCard>[]),
        ],
        freeCells: List.filled(4, null),
        foundations: {for (final s in CardSuit.values) s: <PlayingCard>[]},
      );
      final hint = engine.hint(state);
      expect(hint, isNotNull);
      expect(hint!, contains('foundation'));
    });

    test('hint при пустых ячейках', () {
      final state = FreecellState(
        tableau: [
          const [PlayingCard(suit: CardSuit.hearts, rank: 5, faceUp: true)],
          ...List.generate(7, (_) => <PlayingCard>[]),
        ],
        freeCells: List.filled(4, null),
        foundations: {for (final s in CardSuit.values) s: <PlayingCard>[]},
      );
      final hint = engine.hint(state);
      expect(hint, isNotNull);
    });

    test('hint: на победе null', () {
      final foundations = {
        for (final s in CardSuit.values) s: List.generate(13, (i) => PlayingCard(suit: s, rank: i + 1)),
      };
      final state = FreecellState(
        tableau: List.generate(8, (_) => <PlayingCard>[]),
        freeCells: List.filled(4, null),
        foundations: foundations,
      );
      expect(state.isWin, isTrue);
      expect(engine.hint(state), isNull);
    });

    test('getLegalTableauTargets и getEmptyFreeCells', () {
      final state = FreecellState(
        tableau: [
          const [PlayingCard(suit: CardSuit.hearts, rank: 5, faceUp: true)],
          const [PlayingCard(suit: CardSuit.clubs, rank: 6, faceUp: true)],
          ...List.generate(6, (_) => <PlayingCard>[]),
        ],
        freeCells: const [null, null, PlayingCard(suit: CardSuit.spades, rank: 1, faceUp: true), null],
        foundations: {for (final s in CardSuit.values) s: <PlayingCard>[]},
      );
      final targets = engine.getLegalTableauTargets(state, 0);
      expect(targets, contains(1));
      final emptyCells = engine.getEmptyFreeCells(state);
      expect(emptyCells.length, 3);
    });

    test('autoMoveTableauTop: priority foundation', () {
      final state = FreecellState(
        tableau: [
          const [PlayingCard(suit: CardSuit.hearts, rank: 1, faceUp: true)],
          ...List.generate(7, (_) => <PlayingCard>[]),
        ],
        freeCells: List.filled(4, null),
        foundations: {for (final s in CardSuit.values) s: <PlayingCard>[]},
      );
      final next = engine.autoMoveTableauTop(state, 0);
      expect(next.tableau[0], isEmpty);
      expect(next.foundations[CardSuit.hearts]!.length, 1);
    });

    test('autoFinishStep: обрабатывает все колонки и ячейки', () {
      final state = FreecellState(
        tableau: [
          const [PlayingCard(suit: CardSuit.hearts, rank: 1, faceUp: true)],
          ...List.generate(7, (_) => <PlayingCard>[]),
        ],
        freeCells: List.filled(4, null),
        foundations: {for (final s in CardSuit.values) s: <PlayingCard>[]},
      );
      final next = engine.autoFinishStep(state);
      expect(next.foundations[CardSuit.hearts]!.length, 1);
    });

    test('isWin определяет победу', () {
      final foundations = {
        for (final s in CardSuit.values) s: List.generate(13, (i) => PlayingCard(suit: s, rank: i + 1)),
      };
      final state = FreecellState(
        tableau: List.generate(8, (_) => <PlayingCard>[]),
        freeCells: List.filled(4, null),
        foundations: foundations,
      );
      expect(state.isWin, isTrue);
    });

    test('moveTableauToTableau с fromCardIndex переносит карту', () {
      final state = FreecellState(
        tableau: [
          const [PlayingCard(suit: CardSuit.hearts, rank: 5, faceUp: true)],
          const [PlayingCard(suit: CardSuit.clubs, rank: 6, faceUp: true)],
          ...List.generate(6, (_) => <PlayingCard>[]),
        ],
        freeCells: List.filled(4, null),
        foundations: {for (final s in CardSuit.values) s: <PlayingCard>[]},
      );
      final next = engine.moveTableauToTableau(state, 0, 1, fromCardIndex: 0);
      expect(next.tableau[0], isEmpty);
      expect(next.tableau[1].length, 2);
      expect(next.moves, 1);
    });
  });
}
