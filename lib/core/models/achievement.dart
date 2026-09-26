/// Категория достижения.
enum AchievementCategory { wins, speed, streak, special }

/// Достижение.
class Achievement {
  const Achievement({
    required this.id,
    required this.titleKey,
    required this.descriptionKey,
    required this.category,
    required this.targetValue,
    this.currentValue = 0,
    this.isUnlocked = false,
    this.icon = '🏆',
  });

  final String id;
  final String titleKey;
  final String descriptionKey;
  final AchievementCategory category;
  final int targetValue;
  final int currentValue;
  final bool isUnlocked;
  final String icon;

  double get progress => (currentValue / targetValue).clamp(0.0, 1.0);

  Achievement copyWith({int? currentValue, bool? isUnlocked}) {
    return Achievement(
      id: id,
      titleKey: titleKey,
      descriptionKey: descriptionKey,
      category: category,
      targetValue: targetValue,
      currentValue: currentValue ?? this.currentValue,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      icon: icon,
    );
  }

  factory Achievement.fromJson(Map<String, dynamic> m) {
    return Achievement(
      id: m['id'] as String,
      titleKey: m['titleKey'] as String? ?? '',
      descriptionKey: m['descriptionKey'] as String? ?? '',
      category: AchievementCategory.values[m['category'] as int? ?? 0],
      targetValue: m['targetValue'] as int? ?? 1,
      currentValue: m['currentValue'] as int? ?? 0,
      isUnlocked: m['isUnlocked'] as bool? ?? false,
      icon: m['icon'] as String? ?? '🏆',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'titleKey': titleKey,
    'descriptionKey': descriptionKey,
    'category': category.index,
    'targetValue': targetValue,
    'currentValue': currentValue,
    'isUnlocked': isUnlocked,
    'icon': icon,
  };
}