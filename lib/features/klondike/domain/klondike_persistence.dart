import 'card.dart';
import 'klondike_state.dart';

/// Восстановленная партия Косынки вместе с флагом ежедневной сессии (ТЗ п.15).
class KlondikeLoadedGame {
  const KlondikeLoadedGame(
    this.state,
    this.dailyYmd, {
    this.freeHintsRemaining = 3,
    this.freeAutoFinishRemaining = 1,
    this.dailyRewardRetryUsed = false,
  });
  final KlondikeState state;
  /// Дата `YYYY-MM-DD` ежедневной раздачи, если партия шла в режиме Daily.
  final String? dailyYmd;
  /// Бесплатные подсказки за текущую партию.
  final int freeHintsRemaining;
  /// Оставшиеся бесплатные автодоборы за партию.
  final int freeAutoFinishRemaining;
  /// Использована ли вторая попытка ежедневного челленджа за рекламу.
  final bool dailyRewardRetryUsed;
}

/// Сериализация состояния Косынки для локального сохранения.
class KlondikePersistence {
  static const int _schemaVersion = 1;
  static const String _mode = 'klondike';

  static Map<String, dynamic> toMap(
    KlondikeState state, {
    String? dailyYmd,
    int freeHintsRemaining = 3,
    int freeAutoFinishRemaining = 1,
    bool dailyRewardRetryUsed = false,
  }) {
    return {
      'version': _schemaVersion,
      'mode': _mode,
      if (dailyYmd != null) 'dailyYmd': dailyYmd,
      'freeHintsRemaining': freeHintsRemaining,
      'freeAutoFinishRemaining': freeAutoFinishRemaining,
      'dailyRewardRetryUsed': dailyRewardRetryUsed,
      'payload': {
        'drawCount': state.drawCount,
        'moves': state.moves,
        'elapsedSeconds': state.elapsedSeconds,
        'stock': state.stock.map(_cardToMap).toList(),
        'waste': state.waste.map(_cardToMap).toList(),
        'foundations': {
          for (final suit in CardSuit.values) suit.name: state.foundations[suit]!.map(_cardToMap).toList(),
        },
        'tableau': state.tableau.map((pile) => pile.map(_cardToMap).toList()).toList(),
      },
    };
  }

  static KlondikeLoadedGame? fromMap(Map<String, dynamic>? raw) {
    if (raw == null || raw['mode'] != _mode) return null;
    try {
      // Поддерживаем и новый формат (version + payload), и legacy-формат без payload.
      final payloadRaw = raw['payload'];
      final data = payloadRaw is Map<String, dynamic> ? payloadRaw : raw;
      final dailyYmd = raw['dailyYmd'] as String?;
      final freeHintsRemaining = raw['freeHintsRemaining'] as int? ?? 3;
      final freeAutoFinishRemaining = raw['freeAutoFinishRemaining'] as int? ?? 1;
      final dailyRewardRetryUsed = raw['dailyRewardRetryUsed'] as bool? ?? false;

      final foundationsRaw = (data['foundations'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
      final tableauRaw = (data['tableau'] as List<dynamic>?) ?? const <dynamic>[];

      final state = KlondikeState(
        drawCount: data['drawCount'] as int? ?? 1,
        moves: data['moves'] as int? ?? 0,
        elapsedSeconds: data['elapsedSeconds'] as int? ?? 0,
        stock: _cardListFromRaw(data['stock'] as List<dynamic>?),
        waste: _cardListFromRaw(data['waste'] as List<dynamic>?),
        foundations: {
          for (final suit in CardSuit.values)
            suit: _cardListFromRaw(foundationsRaw[suit.name] as List<dynamic>?),
        },
        tableau: tableauRaw.map((pile) => _cardListFromRaw(pile as List<dynamic>?)).toList(),
      );
      // Проверяем, что загружено ровно 7 колонок (косынка).
      if (state.tableau.length != 7) return null;
      return KlondikeLoadedGame(
        state,
        dailyYmd,
        freeHintsRemaining: freeHintsRemaining,
        freeAutoFinishRemaining: freeAutoFinishRemaining,
        dailyRewardRetryUsed: dailyRewardRetryUsed,
      );
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _cardToMap(PlayingCard card) {
    return {
      'suit': card.suit.name,
      'rank': card.rank,
      'faceUp': card.faceUp,
    };
  }

  static List<PlayingCard> _cardListFromRaw(List<dynamic>? raw) {
    if (raw == null) return const [];
    return raw
        .map((item) => item as Map<String, dynamic>)
        .map(
          (m) => PlayingCard(
            suit: CardSuit.values.firstWhere((s) => s.name == m['suit'], orElse: () => CardSuit.spades),
            rank: m['rank'] as int? ?? 1,
            faceUp: m['faceUp'] as bool? ?? false,
          ),
        )
        .toList();
  }
}
