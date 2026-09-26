/// Тип стиля: рубашка карт или фон стола.
enum StyleType { cardBack, tableBackground }

/// Разблокируемый стиль (рубашка или фон).
class UnlockableStyle {
  const UnlockableStyle({
    required this.id,
    required this.displayNameKey,
    required this.type,
    this.isUnlocked = false,
    this.assetName,
    this.unlockDescriptionKey,
  });

  final String id;
  final String displayNameKey;
  final StyleType type;
  final bool isUnlocked;
  final String? assetName;
  final String? unlockDescriptionKey;

  UnlockableStyle copyWith({bool? isUnlocked}) {
    return UnlockableStyle(
      id: id,
      displayNameKey: displayNameKey,
      type: type,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      assetName: assetName,
      unlockDescriptionKey: unlockDescriptionKey,
    );
  }

  factory UnlockableStyle.fromJson(Map<String, dynamic> m) {
    return UnlockableStyle(
      id: m['id'] as String,
      displayNameKey: m['displayNameKey'] as String? ?? '',
      type: StyleType.values[m['type'] as int? ?? 0],
      isUnlocked: m['isUnlocked'] as bool? ?? false,
      assetName: m['assetName'] as String?,
      unlockDescriptionKey: m['unlockDescriptionKey'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayNameKey': displayNameKey,
    'type': type.index,
    'isUnlocked': isUnlocked,
    if (assetName != null) 'assetName': assetName,
    if (unlockDescriptionKey != null) 'unlockDescriptionKey': unlockDescriptionKey,
  };
}