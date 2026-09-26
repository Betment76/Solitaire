/// Очки для таблицы рекордов (чем выше — тем лучше результат).
int leaderboardScore({
  int? klondikeScore,
  int? moves,
  int? elapsedSeconds,
}) {
  if (klondikeScore != null) return klondikeScore;
  final m = moves ?? 9999;
  final t = elapsedSeconds ?? 0;
  return (100_000 - m * 40 - t).clamp(1, 100_000);
}
