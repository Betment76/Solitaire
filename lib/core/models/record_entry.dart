/// Запись в таблице рекордов.
class RecordEntry {
  const RecordEntry({
    required this.score,
    required this.mode,
    required this.date,
    this.moves,
  });

  final int score;
  final String mode; // 'klondike', 'spider', 'freecell'
  final String date; // 'YYYY-MM-DD'
  final int? moves;

  factory RecordEntry.fromJson(Map<String, dynamic> m) => RecordEntry(
        score: m['score'] as int? ?? 0,
        mode: m['mode'] as String? ?? '',
        date: m['date'] as String? ?? '',
        moves: m['moves'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'score': score,
        'mode': mode,
        'date': date,
        if (moves != null) 'moves': moves,
      };
}