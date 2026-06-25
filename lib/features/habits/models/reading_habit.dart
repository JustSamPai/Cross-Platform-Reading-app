class ReadingHabit {
  const ReadingHabit({
    required this.name,
    this.currentStreak = 0,
    this.targetMinutes = 20,
    this.completedToday = false,
  });

  final String name;
  final int currentStreak;
  final int targetMinutes;
  final bool completedToday;

  ReadingHabit copyWith({
    String? name,
    int? currentStreak,
    int? targetMinutes,
    bool? completedToday,
  }) {
    return ReadingHabit(
      name: name ?? this.name,
      currentStreak: currentStreak ?? this.currentStreak,
      targetMinutes: targetMinutes ?? this.targetMinutes,
      completedToday: completedToday ?? this.completedToday,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'currentStreak': currentStreak,
      'targetMinutes': targetMinutes,
      'completedToday': completedToday,
    };
  }

  factory ReadingHabit.fromMap(Map<dynamic, dynamic> map) {
    return ReadingHabit(
      name: map['name'] as String? ?? 'Reading habit',
      currentStreak: (map['currentStreak'] as num?)?.toInt() ?? 0,
      targetMinutes: (map['targetMinutes'] as num?)?.toInt() ?? 20,
      completedToday: map['completedToday'] as bool? ?? false,
    );
  }
}
