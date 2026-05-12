import 'card.dart';

/// Полное состояние партии Косынки.
class KlondikeState {
  const KlondikeState({
    required this.stock,
    required this.waste,
    required this.foundations,
    required this.tableau,
    required this.drawCount,
    this.moves = 0,
    this.elapsedSeconds = 0,
  });

  final List<PlayingCard> stock;
  final List<PlayingCard> waste;
  final Map<CardSuit, List<PlayingCard>> foundations;
  final List<List<PlayingCard>> tableau;
  final int drawCount;
  final int moves;
  /// Прошедшее время текущей партии в секундах.
  final int elapsedSeconds;

  bool get isWin => foundations.values.every((pile) => pile.length == 13);

  KlondikeState copyWith({
    List<PlayingCard>? stock,
    List<PlayingCard>? waste,
    Map<CardSuit, List<PlayingCard>>? foundations,
    List<List<PlayingCard>>? tableau,
    int? drawCount,
    int? moves,
    int? elapsedSeconds,
  }) {
    return KlondikeState(
      stock: stock ?? this.stock,
      waste: waste ?? this.waste,
      foundations: foundations ?? this.foundations,
      tableau: tableau ?? this.tableau,
      drawCount: drawCount ?? this.drawCount,
      moves: moves ?? this.moves,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
    );
  }
}
