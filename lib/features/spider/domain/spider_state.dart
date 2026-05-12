import '../../../core/models/card.dart';

/// Состояние партии Паук (4 масти, 2 колоды).
class SpiderState {
  const SpiderState({
    required this.stock,
    required this.tableau,
    this.completedSequences = 0,
    this.completedSuits = const [],
    this.moves = 0,
  });

  final List<PlayingCard> stock;
  final List<List<PlayingCard>> tableau;
  final int completedSequences;
  final List<CardSuit> completedSuits;
  final int moves;

  bool get isWin => completedSequences >= 8;

  SpiderState copyWith({
    List<PlayingCard>? stock,
    List<List<PlayingCard>>? tableau,
    int? completedSequences,
    List<CardSuit>? completedSuits,
    int? moves,
  }) {
    return SpiderState(
      stock: stock ?? this.stock,
      tableau: tableau ?? this.tableau,
      completedSequences: completedSequences ?? this.completedSequences,
      completedSuits: completedSuits ?? this.completedSuits,
      moves: moves ?? this.moves,
    );
  }
}
