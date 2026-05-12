/// Масть карты.
enum CardSuit { hearts, diamonds, clubs, spades }

/// Цвет карты для проверки чередования в колонках.
enum CardColor { red, black }

/// Игровая карта.
class PlayingCard {
  const PlayingCard({
    required this.suit,
    required this.rank,
    this.faceUp = false,
  });

  final CardSuit suit;
  final int rank; // 1..13, где 1 = Туз, 13 = Король
  final bool faceUp;

  CardColor get color {
    switch (suit) {
      case CardSuit.hearts:
      case CardSuit.diamonds:
        return CardColor.red;
      case CardSuit.clubs:
      case CardSuit.spades:
        return CardColor.black;
    }
  }

  PlayingCard copyWith({bool? faceUp}) {
    return PlayingCard(suit: suit, rank: rank, faceUp: faceUp ?? this.faceUp);
  }
}
