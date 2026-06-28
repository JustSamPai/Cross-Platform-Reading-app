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

  test('awards larger bonuses on every fifth and tenth page', () {
    final reward = store.recordPagesThrough(
      documentId: 'book-1',
      completedPages: 10,
      totalPages: 100,
    );

    expect(reward.pageXp, 10);
    expect(reward.milestoneXp, 15);
    expect(reward.completionXp, 0);
    expect(reward.xpEarned, 25);
    expect(store.load().pagesRead, 10);
    expect(store.load().fifthPageBonuses, 1);
    expect(store.load().tenPageBonuses, 1);
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
    expect(store.load().totalXp, 25);
  });

  test('awards a completion bonus and increases the reading level', () {
    final reward = store.recordPagesThrough(
      documentId: 'book-1',
      completedPages: 100,
      totalPages: 100,
    );

    expect(reward.pageXp, 100);
    expect(reward.milestoneXp, 150);
    expect(reward.completionXp, 25);
    expect(reward.progress.currentLevel, 3);
    expect(reward.progress.currentXp, 25);
    expect(reward.progress.completedBooks, 1);
    expect(reward.progress.readingTitle, 'Fan');
  });

  test('counts unique web chapters and rewards being caught up', () {
    store.recordPage(
      documentId: 'novel-1',
      pageId: 'chapter-1',
      totalPages: 2,
      pageNumber: 1,
    );
    final reward = store.recordPage(
      documentId: 'novel-1',
      pageId: 'chapter-2',
      totalPages: 2,
      pageNumber: 2,
    );
    final repeatedReward = store.recordPage(
      documentId: 'novel-1',
      pageId: 'chapter-2',
      totalPages: 2,
      pageNumber: 2,
    );

    expect(reward.completionXp, 25);
    expect(reward.progress.completedBooks, 1);
    expect(repeatedReward.xpEarned, 0);
  });
}
