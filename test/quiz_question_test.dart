import 'package:flutter_reading_portfolio_app/features/quiz/models/quiz_question.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('isCorrect returns true for the correct answer', () {
    final question = QuizQuestion(
      prompt: 'Example?',
      answers: const ['A', 'B'],
      correctIndex: 1,
    );

    expect(question.isCorrect(1), isTrue);
    expect(question.isCorrect(0), isFalse);
    expect(question.correctAnswer, 'B');
  });

  test('requires the correct answer index to exist', () {
    expect(
      () => QuizQuestion(
        prompt: 'Broken?',
        answers: const ['A', 'B'],
        correctIndex: 2,
      ),
      throwsAssertionError,
    );
  });
}
