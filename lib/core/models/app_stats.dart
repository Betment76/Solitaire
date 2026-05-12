/// Режим для записи победы в статистику.
enum SolitaireVariant {
  klondike,
  spider,
  freecell,
}

/// Модель статистики MVP (общие и по режимам).
class AppStats {
  const AppStats({
    this.wins = 0,
    this.winsKlondike = 0,
    this.winsSpider = 0,
    this.winsFreecell = 0,
    this.bestScore = 0,
    this.winStreak = 0,
  });

  /// Всего побед (все режимы).
  final int wins;
  final int winsKlondike;
  final int winsSpider;
  final int winsFreecell;
  final int bestScore;
  final int winStreak;

  factory AppStats.fromJson(Map<String, dynamic> m) {
    final wins = m['wins'] as int? ?? 0;
    var wk = m['winsKlondike'] as int? ?? 0;
    var ws = m['winsSpider'] as int? ?? 0;
    var wf = m['winsFreecell'] as int? ?? 0;
    // Миграция v1: в старом JSON не было разбивки — относим все победы к Косынке.
    if (wk + ws + wf == 0 && wins > 0) {
      wk = wins;
    }
    return AppStats(
      wins: wins,
      winsKlondike: wk,
      winsSpider: ws,
      winsFreecell: wf,
      bestScore: m['bestScore'] as int? ?? 0,
      winStreak: m['winStreak'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'wins': wins,
        'winsKlondike': winsKlondike,
        'winsSpider': winsSpider,
        'winsFreecell': winsFreecell,
        'bestScore': bestScore,
        'winStreak': winStreak,
      };

  AppStats copyWith({
    int? wins,
    int? winsKlondike,
    int? winsSpider,
    int? winsFreecell,
    int? bestScore,
    int? winStreak,
  }) {
    return AppStats(
      wins: wins ?? this.wins,
      winsKlondike: winsKlondike ?? this.winsKlondike,
      winsSpider: winsSpider ?? this.winsSpider,
      winsFreecell: winsFreecell ?? this.winsFreecell,
      bestScore: bestScore ?? this.bestScore,
      winStreak: winStreak ?? this.winStreak,
    );
  }
}
