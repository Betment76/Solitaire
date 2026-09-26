import '../../../core/models/card.dart';
import 'spider_state.dart';

/// Раздача + мета партии (отмены, подсказки, масти).
class SpiderLoadedGame {
  const SpiderLoadedGame(
    this.state, {
    this.undoBudget = 5,
    this.freeHintsRemaining = 3,
    this.suitCount = 1,
  });
  final SpiderState state;
  final int undoBudget;
  final int freeHintsRemaining;
  /// Количество мастей партии (для испытаний и статистики).
  final int suitCount;
}

/// Сериализация состояния Паука для локального сохранения.
class SpiderPersistence {
  static const int _schemaVersion = 1;
  static const String _mode = 'spider';

  static Map<String, dynamic> toMap(
    SpiderState state, {
    int undoBudget = 5,
    int freeHintsRemaining = 3,
    int suitCount = 1,
  }) {
    return {
      'version': _schemaVersion,
      'mode': _mode,
      'undoBudget': undoBudget,
      'freeHintsRemaining': freeHintsRemaining,
      'suitCount': suitCount,
      'payload': {
        'moves': state.moves,
        'completedSequences': state.completedSequences,
        'completedSuits': state.completedSuits.map((s) => s.name).toList(),
        'stock': state.stock.map(_cardToMap).toList(),
        'tableau': state.tableau
            .map((pile) => pile.map(_cardToMap).toList())
            .toList(),
      },
    };
  }

  static SpiderLoadedGame? fromMap(Map<String, dynamic>? raw) {
    if (raw == null || raw['mode'] != _mode) return null;
    try {
      final undoBudget = raw['undoBudget'] as int? ?? 5;
      final freeHintsRemaining = raw['freeHintsRemaining'] as int? ?? 3;
      // В сейвах старых версий поля нет — считаем партию одомастной.
      final suitCount = (raw['suitCount'] as int?)?.clamp(1, 4) ?? 1;
      // Поддерживаем и новый формат (version + payload), и legacy-формат без payload.
      final payloadRaw = raw['payload'];
      final data = payloadRaw is Map<String, dynamic> ? payloadRaw : raw;

      final tableauRaw =
          (data['tableau'] as List<dynamic>?) ?? const <dynamic>[];
      final rawSuits = data['completedSuits'] as List<dynamic>?;
      // Неизвестная масть — битый сейв: бросаем, снаружи вернётся null (новая игра).
      final completedSuits = rawSuits
          ?.map((e) => CardSuit.values.firstWhere((s) => s.name == e))
          .toList() ??
          <CardSuit>[];
      final result = SpiderState(
        moves: data['moves'] as int? ?? 0,
        completedSequences: data['completedSequences'] as int? ?? 0,
        completedSuits: completedSuits,
        stock: _cardListFromRaw(data['stock'] as List<dynamic>?),
        tableau: tableauRaw
            .map((pile) => _cardListFromRaw(pile as List<dynamic>?))
            .toList(),
      );
      if (result.tableau.length != 10) return null;
      return SpiderLoadedGame(
        result,
        undoBudget: undoBudget,
        freeHintsRemaining: freeHintsRemaining,
        suitCount: suitCount,
      );
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _cardToMap(PlayingCard card) {
    return {'suit': card.suit.name, 'rank': card.rank, 'faceUp': card.faceUp};
  }

  static PlayingCard _cardFromMap(Map<String, dynamic> m) {
    final suitName = m['suit'] as String?;
    final rank = m['rank'] as int?;
    // Некорректная масть или ранг — битый сейв: бросаем, чтобы загрузка вернула null.
    if (suitName == null || rank == null || rank < 1 || rank > 13) {
      throw const FormatException('Invalid card in save');
    }
    return PlayingCard(
      suit: CardSuit.values.firstWhere((s) => s.name == suitName),
      rank: rank,
      faceUp: m['faceUp'] as bool? ?? false,
    );
  }

  static List<PlayingCard> _cardListFromRaw(List<dynamic>? raw) {
    if (raw == null) return const [];
    return raw
        .map((item) => _cardFromMap(item as Map<String, dynamic>))
        .toList();
  }
}
