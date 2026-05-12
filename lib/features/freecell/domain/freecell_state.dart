import '../../../core/models/card.dart';

/// Состояние партии FreeCell.
class FreecellState {
  const FreecellState({
    required this.tableau,
    required this.freeCells,
    required this.foundations,
    this.moves = 0,
    this.extraFreeCellSlots = 0,
    this.freeExtraCellUnlockPending = true,
  });

  final List<List<PlayingCard>> tableau;
  final List<PlayingCard?> freeCells;
  final Map<CardSuit, List<PlayingCard>> foundations;
  final int moves;
  /// Сколько ячеек добавлено поверх базовых четырёх (макс. 4: 1 бесплатно + 3 за рекламу).
  final int extraFreeCellSlots;
  /// Ещё не использована одна бесплатная добавка ячейки на эту партию.
  final bool freeExtraCellUnlockPending;

  bool get isWin => foundations.values.every((pile) => pile.length == 13);

  FreecellState copyWith({
    List<List<PlayingCard>>? tableau,
    List<PlayingCard?>? freeCells,
    Map<CardSuit, List<PlayingCard>>? foundations,
    int? moves,
    int? extraFreeCellSlots,
    bool? freeExtraCellUnlockPending,
  }) {
    return FreecellState(
      tableau: tableau ?? this.tableau,
      freeCells: freeCells ?? this.freeCells,
      foundations: foundations ?? this.foundations,
      moves: moves ?? this.moves,
      extraFreeCellSlots: extraFreeCellSlots ?? this.extraFreeCellSlots,
      freeExtraCellUnlockPending:
          freeExtraCellUnlockPending ?? this.freeExtraCellUnlockPending,
    );
  }
}
