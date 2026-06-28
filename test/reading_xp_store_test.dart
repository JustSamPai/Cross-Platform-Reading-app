import 'dart:io';

import 'package:flutter_reading_portfolio_app/core/storage/reading_storage.dart';
import 'package:flutter_reading_portfolio_app/features/habits/data/reading_xp_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;
  late Box<dynamic> box;
  late ReadingXpStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('readflow_xp_test_');
    Hive.init(tempDir.path);
    box = await Hive.openBox(ReadingStorage.boxName);
    store = ReadingXpStore(box: box);
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('awards page XP and a bonus for every ten pages', () {
    final reward = store.recordPagesThrough(
      documentId: 'book-1',
      completedPages: 10,
      totalPages: 100,
    );

    expect(reward.pageXp, 10);
    expect(reward.milestoneXp, 5);
    expect(reward.completionXp, 0);
    expect(reward.xpEarned, 15);
    expect(store.load().pagesRead, 10);
  });

  test('does not award XP twice for the same pages', () {
    store.recordPagesThrough(
      documentId: 'book-1',
      completedPages: 10,
      totalPages: 100,
    );

    final repeatedReward = store.recordPagesThrough(
      documentId: 'book-1',
      completedPages: 10,
      totalPages: 100,
    );

    expect(repeatedReward.xpEarned, 0);
    expect(store.load().totalXp, 15);
  });

  test('awards a completion bonus and increases the reading level', () {
    final reward = store.recordPagesThrough(
      documentId: 'book-1',
      completedPages: 100,
      totalPages: 100,
    );

    expect(reward.pageXp, 100);
    expect(reward.milestoneXp, 50);
    expect(reward.completionXp, 25);
    expect(reward.progress.currentLevel, 2);
    expect(reward.progress.currentXp, 75);
    expect(reward.progress.completedBooks, 1);
  });

  test('counts unique web chapters and rewards being caught up', () {
    store.recordPage(
      documentId: 'novel-1',
      pageId: 'chapter-1',
      totalPages: 2,
    );
    final reward = store.recordPage(
      documentId: 'novel-1',
      pageId: 'chapter-2',
      totalPages: 2,
    );
    final repeatedReward = store.recordPage(
      documentId: 'novel-1',
      pageId: 'chapter-2',
      totalPages: 2,
    );

    expect(reward.completionXp, 25);
    expect(reward.progress.completedBooks, 1);
    expect(repeatedReward.xpEarned, 0);
  });
}
