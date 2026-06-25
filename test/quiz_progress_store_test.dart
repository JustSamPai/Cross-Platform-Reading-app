import 'dart:io';

import 'package:flutter_reading_portfolio_app/core/storage/reading_storage.dart';
import 'package:flutter_reading_portfolio_app/features/quiz/data/quiz_progress_store.dart';
import 'package:flutter_reading_portfolio_app/features/quiz/data/sample_questions.dart';
import 'package:flutter_reading_portfolio_app/features/quiz/models/quiz_progress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;
  late Box<dynamic> box;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('readflow_quiz_test_');
    Hive.init(tempDir.path);
    box = await Hive.openBox(ReadingStorage.boxName);
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('awards XP and marks a quiz deck complete', () {
    final store = QuizProgressStore(box: box);
    final deck = sampleQuizDecks.first;

    final reward = store.completeDeck(
      deck,
      QuizCompletion(
        correctAnswers: deck.questions.length,
        totalQuestions: deck.questions.length,
      ),
    );
    final progress = store.load();

    expect(reward.xpEarned, 10);
    expect(progress.currentLevel, 2);
    expect(progress.isDeckCompleted(deck.id), isTrue);
  });
}
