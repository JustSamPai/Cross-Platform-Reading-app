import 'package:hive/hive.dart';

import '../../../core/storage/reading_storage.dart';
import '../../../core/utils/date_keys.dart';
import '../models/reading_habit.dart';
import 'sample_habits.dart';

class ReadingHabitStore {
  ReadingHabitStore({Box<dynamic>? box}) : _box = box ?? ReadingStorage.box;

  static const _startDateKey = 'habits.startDate';
  static const _currentHabitsKey = 'habits.current';
  static const _dayPrefix = 'habits.day.';
  static const _percentPrefix = 'habits.percent.';

  final Box<dynamic> _box;

  DateTime get startDate {
    final stored = _box.get(_startDateKey) as String?;
    return createDateTimeObject(stored ?? todaysDateFormatted());
  }

  void ensureInitialized({DateTime? today}) {
    if (_box.get(_startDateKey) == null) {
      _box.put(_startDateKey, todaysDateFormatted(today));
    }

    if (_box.get(_currentHabitsKey) == null) {
      _box.put(
        _currentHabitsKey,
        sampleHabits.map((habit) => habit.toMap()).toList(),
      );
    }
  }

  List<ReadingHabit> loadToday({DateTime? today}) {
    ensureInitialized(today: today);

    final dateKey = todaysDateFormatted(today);
    final storedDay = _box.get(_dayKey(dateKey));
    if (storedDay != null) {
      return _decodeHabits(storedDay);
    }

    return _decodeHabits(_box.get(_currentHabitsKey))
        .map((habit) => habit.copyWith(completedToday: false))
        .toList();
  }

  void saveToday(List<ReadingHabit> habits, {DateTime? today}) {
    ensureInitialized(today: today);

    final dateKey = todaysDateFormatted(today);
    final normalized = _withUpdatedStreaks(habits, dateKey);

    _box.put(
        _dayKey(dateKey), normalized.map((habit) => habit.toMap()).toList());
    _box.put(
      _currentHabitsKey,
      normalized
          .map((habit) => habit.copyWith(completedToday: false).toMap())
          .toList(),
    );
    _box.put(_percentKey(dateKey),
        _completionPercent(normalized).toStringAsFixed(1));
  }

  List<ReadingHabit> toggleHabit(int index, bool completed, {DateTime? today}) {
    final habits = loadToday(today: today);
    if (index < 0 || index >= habits.length) {
      return habits;
    }

    habits[index] = habits[index].copyWith(completedToday: completed);
    saveToday(habits, today: today);
    return loadToday(today: today);
  }

  List<ReadingHabit> addHabit(String name, int targetMinutes,
      {DateTime? today}) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return loadToday(today: today);
    }

    final habits = loadToday(today: today)
      ..add(
        ReadingHabit(
          name: trimmedName,
          targetMinutes: targetMinutes,
        ),
      );
    saveToday(habits, today: today);
    return loadToday(today: today);
  }

  List<ReadingHabit> updateHabit(
    int index,
    String name,
    int targetMinutes, {
    DateTime? today,
  }) {
    final habits = loadToday(today: today);
    if (index < 0 || index >= habits.length || name.trim().isEmpty) {
      return habits;
    }

    habits[index] = habits[index].copyWith(
      name: name.trim(),
      targetMinutes: targetMinutes,
    );
    saveToday(habits, today: today);
    return loadToday(today: today);
  }

  List<ReadingHabit> deleteHabit(int index, {DateTime? today}) {
    final habits = loadToday(today: today);
    if (index < 0 || index >= habits.length) {
      return habits;
    }

    habits.removeAt(index);
    saveToday(habits, today: today);
    return loadToday(today: today);
  }

  Map<DateTime, int> heatMapDataset({DateTime? today}) {
    ensureInitialized(today: today);

    final endDate = dateOnly(today ?? DateTime.now());
    final values = <DateTime, int>{};

    for (final day in daysBetween(startDate, endDate)) {
      final dateKey = convertDateTimeToString(day);
      final strength =
          (_completionPercentForDay(dateKey) * 10).round().clamp(0, 10).toInt();
      values[day] = strength;
    }

    return values;
  }

  List<ReadingHabit> _decodeHabits(Object? raw) {
    if (raw is! List) {
      return const [];
    }

    return raw.map((entry) {
      if (entry is Map) {
        return ReadingHabit.fromMap(entry);
      }

      if (entry is List && entry.length >= 2) {
        return ReadingHabit(
          name: entry[0].toString(),
          completedToday: entry[1] == true,
        );
      }

      return const ReadingHabit(name: 'Reading habit');
    }).toList();
  }

  List<ReadingHabit> _withUpdatedStreaks(
      List<ReadingHabit> habits, String todayKey) {
    return habits.map((habit) {
      return habit.copyWith(
        currentStreak: _calculateStreak(
          habit.name,
          todayKey,
          todayCompleted: habit.completedToday,
        ),
      );
    }).toList();
  }

  int _calculateStreak(
    String habitName,
    String todayKey, {
    required bool todayCompleted,
  }) {
    var streak = 0;
    var cursor = createDateTimeObject(todayKey);

    while (true) {
      final cursorKey = convertDateTimeToString(cursor);
      final completed = cursorKey == todayKey
          ? todayCompleted
          : _habitCompletedOn(habitName, cursorKey);

      if (completed) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
        continue;
      }

      if (cursorKey == todayKey) {
        cursor = cursor.subtract(const Duration(days: 1));
        continue;
      }

      break;
    }

    return streak;
  }

  bool _habitCompletedOn(String habitName, String dateKey) {
    return _decodeHabits(_box.get(_dayKey(dateKey))).any(
      (habit) => habit.name == habitName && habit.completedToday,
    );
  }

  double _completionPercentForDay(String dateKey) {
    final storedPercent = _box.get(_percentKey(dateKey));
    if (storedPercent is num) {
      return storedPercent.toDouble();
    }
    if (storedPercent is String) {
      return double.tryParse(storedPercent) ??
          _completionPercent(_decodeHabits(_box.get(_dayKey(dateKey))));
    }

    return _completionPercent(_decodeHabits(_box.get(_dayKey(dateKey))));
  }

  double _completionPercent(List<ReadingHabit> habits) {
    if (habits.isEmpty) {
      return 0;
    }

    final completed = habits.where((habit) => habit.completedToday).length;
    return completed / habits.length;
  }

  String _dayKey(String dateKey) => '$_dayPrefix$dateKey';

  String _percentKey(String dateKey) => '$_percentPrefix$dateKey';
}
