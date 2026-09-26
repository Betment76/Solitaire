import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_table_background.dart';
import '../../core/models/app_settings.dart';
import '../../core/models/card.dart';
import '../../core/providers.dart';

/// Метка ранга карты: 1 -> A, 11 -> J, 12 -> Q, 13 -> K.
String cardRankLabel(int rank) {
  switch (rank) {
    case 1:
      return 'A';
    case 11:
      return 'J';
    case 12:
      return 'Q';
    case 13:
      return 'K';
    default:
      return '$rank';
  }
}

/// Символ масти карты.
String cardSuitSymbol(CardSuit suit) {
  switch (suit) {
    case CardSuit.hearts:
      return '♥';
    case CardSuit.diamonds:
      return '♦';
    case CardSuit.clubs:
      return '♣';
    case CardSuit.spades:
      return '♠';
  }
}

/// Короткое имя карты для текстов подсказок, например `10♥`.
String cardName(PlayingCard card) =>
    '${cardRankLabel(card.rank)}${cardSuitSymbol(card.suit)}';

/// Единый виджет игровой карты для всех режимов: лицо (classic/minimal)
/// и рубашка по настройкам «Стиль». Кегли шрифтов пропорциональны высоте,
/// поэтому вид карты одинаков на любом размере.
class PlayingCardView extends ConsumerWidget {
  const PlayingCardView({
    super.key,
    required this.card,
    this.width,
    this.height,
    this.faceStyleOverride,
  });

  /// Только рубашка (колода, пустые слоты домов, фон собранной масти).
  const PlayingCardView.back({super.key, this.width, this.height})
      : card = null,
        faceStyleOverride = null;

  final PlayingCard? card;
  final double? width;
  final double? height;

  /// Явный стиль лица вместо настроек — для превью в выборе стиля.
  final CardFaceStyle? faceStyleOverride;

  static const Color _redInk = Color(0xFFB42020);
  static const Color _blackInk = Color(0xFF1B1B1B);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final back = ref.watch(
      settingsProvider.select((v) => v.asData?.value.cardBack),
    );
    final faceStyle = ref.watch(
      settingsProvider.select((v) => v.asData?.value.cardFaceStyle),
    );
    final c = card;
    if (c == null || !c.faceUp) {
      return _buildBack(back ?? 'blue');
    }
    return _buildFace(c, faceStyleOverride ?? faceStyle ?? CardFaceStyle.classic);
  }

  Widget _buildBack(String back) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: cardBackGradientColors(back),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white70, width: 1.2),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
      ),
    );
  }

  Widget _buildFace(PlayingCard c, CardFaceStyle faceStyle) {
    final h = height ?? 84;
    final ink = c.color == CardColor.red ? _redInk : _blackInk;
    final rankText = cardRankLabel(c.rank);
    final suitText = cardSuitSymbol(c.suit);
    return Container(
      width: width,
      height: height,
      // В minimal ранг позиционируется вручную — без внутреннего отступа.
      padding: faceStyle == CardFaceStyle.minimal
          ? EdgeInsets.zero
          : EdgeInsets.all(h * 0.07),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
      ),
      child: faceStyle == CardFaceStyle.minimal
          ? Stack(
              children: [
                // Ранг и масть в ряд слева сверху; FittedBox не даёт «10» вылезти на узких картах.
                Positioned(
                  left: h * 0.048,
                  top: 0,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          rankText,
                          style: TextStyle(
                            color: ink,
                            fontWeight: FontWeight.w800,
                            fontSize: h * 0.226,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(left: h * 0.036),
                          child: Text(
                            suitText,
                            style: TextStyle(
                              color: ink,
                              fontWeight: FontWeight.w800,
                              fontSize: h * 0.167,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: Text(
                    suitText,
                    style: TextStyle(
                      color: ink.withValues(alpha: 0.24),
                      fontWeight: FontWeight.w800,
                      fontSize: h * 0.333,
                    ),
                  ),
                ),
              ],
            )
          : Stack(
              children: [
                Text(
                  '$rankText\n$suitText',
                  style: TextStyle(
                    color: ink,
                    fontWeight: FontWeight.w800,
                    fontSize: h * 0.167,
                    height: 1.0,
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: Text(
                    suitText,
                    style: TextStyle(
                      color: ink.withValues(alpha: 0.30),
                      fontWeight: FontWeight.w800,
                      fontSize: h * 0.31,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Transform.rotate(
                    angle: 3.1415926,
                    child: Text(
                      '$rankText\n$suitText',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w800,
                        fontSize: h * 0.167,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
