class ReadingHabit {
  const ReadingHabit({
    required this.name,
    required this.currentStreak,
    required this.targetMinutes,
    required this.completedToday,
  });

  final String name;
  final int currentStreak;
  final int targetMinutes;
  final bool completedToday;
}
