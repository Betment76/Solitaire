/// Статус испытания.
enum ChallengeStatus { locked, active, completed }

/// Испытание (режим испытаний).
class Challenge {
  const Challenge({
    required this.id,
    required this.titleKey,
    required this.descriptionKey,
    required this.mode,
    this.targetMoves,
    this.targetTime,
    this.noUndo = false,
    this.noCells = false,
    this.fourSuits = false,
    this.unlockStyleId,
    this.status = ChallengeStatus.locked,
  });

  final String id;
  final String titleKey;
  final String descriptionKey;

  /// К какому режиму относится: 'klondike', 'spider', 'freecell'.
  final String mode;

  /// Целевое количество ходов (например, < 120).
  final int? targetMoves;

  /// Целевое время в секундах (например, < 180).
  final int? targetTime;

  /// Победа без Undo.
  final bool noUndo;

  /// FreeCell: без использования ячеек.
  final bool noCells;

  /// Spider: 4 масти.
  final bool fourSuits;

  /// ID стиля, который открывается за прохождение (nullable).
  final String? unlockStyleId;

  final ChallengeStatus status;

  Challenge copyWith({ChallengeStatus? status}) {
    return Challenge(
      id: id,
      titleKey: titleKey,
      descriptionKey: descriptionKey,
      mode: mode,
      targetMoves: targetMoves,
      targetTime: targetTime,
      noUndo: noUndo,
      noCells: noCells,
      fourSuits: fourSuits,
      unlockStyleId: unlockStyleId,
      status: status ?? this.status,
    );
  }

  factory Challenge.fromJson(Map<String, dynamic> m) {
    return Challenge(
      id: m['id'] as String,
      titleKey: m['titleKey'] as String? ?? '',
      descriptionKey: m['descriptionKey'] as String? ?? '',
      mode: m['mode'] as String? ?? 'klondike',
      targetMoves: m['targetMoves'] as int?,
      targetTime: m['targetTime'] as int?,
      noUndo: m['noUndo'] as bool? ?? false,
      noCells: m['noCells'] as bool? ?? false,
      fourSuits: m['fourSuits'] as bool? ?? false,
      unlockStyleId: m['unlockStyleId'] as String?,
      status: ChallengeStatus.values[m['status'] as int? ?? 0],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'titleKey': titleKey,
    'descriptionKey': descriptionKey,
    'mode': mode,
    if (targetMoves != null) 'targetMoves': targetMoves,
    if (targetTime != null) 'targetTime': targetTime,
    'noUndo': noUndo,
    'noCells': noCells,
    'fourSuits': fourSuits,
    if (unlockStyleId != null) 'unlockStyleId': unlockStyleId,
    'status': status.index,
  };
}