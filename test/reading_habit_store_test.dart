import 'dart:io';

import 'package:flutter_reading_portfolio_app/core/storage/reading_storage.dart';
import 'package:flutter_reading_portfolio_app/features/habits/data/reading_habit_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;
  late Box<dynamic> box;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('readflow_habits_test_');
    Hive.init(tempDir.path);
    box = await Hive.openBox(ReadingStorage.boxName);
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('loads default habits and records daily completion strength', () {
    final store = ReadingHabitStore(box: box);
    final today = DateTime(2026, 6, 24);

    final habits = store.loadToday(today: today);
    final updated = store.toggleHabit(0, true, today: today);
    final heatMap = store.heatMapDataset(today: today);

    expect(habits, isNotEmpty);
    expect(updated.first.completedToday, isTrue);
    expect(updated.first.currentStreak, 1);
    expect(heatMap[DateTime(2026, 6, 24)], greaterThan(0));
  });
}
