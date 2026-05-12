import 'package:flutter_test/flutter_test.dart';
import 'package:solitaire/features/klondike/domain/card.dart';
import 'package:solitaire/features/klondike/domain/klondike_persistence.dart';
import 'package:solitaire/features/klondike/domain/klondike_state.dart';

void main() {
  test('сериализация и восстановление состояния Косынки работает', () {
    final source = KlondikeState(
      stock: const [PlayingCard(suit: CardSuit.spades, rank: 9)],
      waste: const [PlayingCard(suit: CardSuit.hearts, rank: 1, faceUp: true)],
      drawCount: 3,
      moves: 12,
      foundations: {
        CardSuit.hearts: const [PlayingCard(suit: CardSuit.hearts, rank: 1, faceUp: true)],
        CardSuit.diamonds: const [],
        CardSuit.clubs: const [],
        CardSuit.spades: const [],
      },
      tableau: [
        const [PlayingCard(suit: CardSuit.clubs, rank: 13, faceUp: true)],
        const [],
        const [],
        const [],
        const [],
        const [],
        const [],
      ],
    );

    final map = KlondikePersistence.toMap(source);
    final restored = KlondikePersistence.fromMap(map);

    expect(restored, isNotNull);
    expect(restored!.dailyYmd, isNull);
    expect(restored.state.drawCount, 3);
    expect(restored.state.moves, 12);
    expect(restored.state.stock.length, 1);
    expect(restored.state.waste.length, 1);
    expect(restored.state.foundations[CardSuit.hearts]!.length, 1);
    expect(restored.state.tableau.first.length, 1);
  });

  test('ежедневная метка dailyYmd сохраняется в JSON сейва', () {
    final source = KlondikeState(
      stock: const [],
      waste: const [],
      drawCount: 1,
      moves: 0,
      foundations: {
        for (final s in CardSuit.values) s: const <PlayingCard>[],
      },
      tableau: List.generate(7, (_) => const <PlayingCard>[]),
    );
    const ymd = '2026-05-04';
    final map = KlondikePersistence.toMap(source, dailyYmd: ymd);
    final restored = KlondikePersistence.fromMap(map);
    expect(restored?.dailyYmd, ymd);
    expect(restored?.state.drawCount, 1);
  });
}
