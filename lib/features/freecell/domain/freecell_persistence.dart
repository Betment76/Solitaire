import '../../../core/models/card.dart';
import 'freecell_state.dart';

/// Сохранённая партия и метаданные (отмены за партию).
class FreecellLoadedGame {
  const FreecellLoadedGame(
    this.state, {
    this.undoBudget = 5,
  });
  final FreecellState state;
  /// Бесплатные отмены за партию (добор через rewarded).
  final int undoBudget;
}

/// Сериализация состояния FreeCell для локального сохранения.
class FreecellPersistence {
  static const int _schemaVersion = 1;
  static const String _mode = 'freecell';
  /// Максимум доп. ячеек за партию (1 без рекламы + 3 за рекламу).
  static const int maxExtraFreeCells = 4;

  static Map<String, dynamic> toMap(
    FreecellState state, {
    int undoBudget = 5,
  }) {
    return {
      'version': _schemaVersion,
      'mode': _mode,
      'payload': {
        'moves': state.moves,
        'extraFreeCellSlots': state.extraFreeCellSlots,
        'freeExtraCellUnlockPending': state.freeExtraCellUnlockPending,
        'undoBudget': undoBudget,
        'tableau': state.tableau
            .map((pile) => pile.map(_cardToMap).toList())
            .toList(),
        'freeCells': state.freeCells
            .map((card) => card == null ? null : _cardToMap(card))
            .toList(),
        'foundations': {
          for (final suit in CardSuit.values)
            suit.name: state.foundations[suit]!.map(_cardToMap).toList(),
        },
      },
    };
  }

  static FreecellLoadedGame? fromMap(Map<String, dynamic>? raw) {
    if (raw == null || raw['mode'] != _mode) return null;
    try {
      // Поддерживаем и новый формат (version + payload), и legacy-формат без payload.
      final payloadRaw = raw['payload'];
      final data = payloadRaw is Map<String, dynamic> ? payloadRaw : raw;

      final tableauRaw =
          (data['tableau'] as List<dynamic>?) ?? const <dynamic>[];
      final foundationsRaw =
          (data['foundations'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      final extraSlots =
          (data['extraFreeCellSlots'] as int?)?.clamp(0, maxExtraFreeCells) ?? 0;
      // freeAutoFinishRemaining в старых сейвах — игнорируем, автодобор без лимита.
      final undoBudget = (data['undoBudget'] as int?)?.clamp(0, 999) ?? 5;
      final pendingRaw = data['freeExtraCellUnlockPending'] as bool?;
      final legacyBadge = data['extraCellBadgeRemaining'] as int?;
      // Старые сейвы: без поля — только при 0 добавок; badge 0 означал «нужна реклама для единственной ячейки».
      final freeExtraCellUnlockPending = pendingRaw ??
          (extraSlots == 0 &&
              (legacyBadge == null || legacyBadge == 1));
      final freeCellsRaw =
          (data['freeCells'] as List<dynamic>?) ??
          List<dynamic>.filled(4 + extraSlots, null);

      final parsedCells = freeCellsRaw
          .map(
            (item) => item == null
                ? null
                : _cardFromMap(item as Map<String, dynamic>),
          )
          .toList();

      final cellCount = 4 + extraSlots;
      final normalizedCells = List<PlayingCard?>.generate(
        cellCount,
        (i) => i < parsedCells.length ? parsedCells[i] : null,
      );

      final result = FreecellState(
        moves: data['moves'] as int? ?? 0,
        tableau: tableauRaw
            .map((pile) => _cardListFromRaw(pile as List<dynamic>?))
            .toList(),
        freeCells: normalizedCells,
        foundations: {
          for (final suit in CardSuit.values)
            suit: _cardListFromRaw(foundationsRaw[suit.name] as List<dynamic>?),
        },
        extraFreeCellSlots: extraSlots,
        freeExtraCellUnlockPending: freeExtraCellUnlockPending,
      );
      if (result.tableau.length != 8) return null;
      return FreecellLoadedGame(
        result,
        undoBudget: undoBudget,
      );
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _cardToMap(PlayingCard card) {
    return {'suit': card.suit.name, 'rank': card.rank, 'faceUp': card.faceUp};
  }

  static PlayingCard _cardFromMap(Map<String, dynamic> m) {
    return PlayingCard(
      suit: CardSuit.values.firstWhere(
        (s) => s.name == m['suit'],
        orElse: () => CardSuit.spades,
      ),
      rank: m['rank'] as int? ?? 1,
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
