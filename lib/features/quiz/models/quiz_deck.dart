import 'quiz_question.dart';

class QuizDeck {
  const QuizDeck({
    required this.id,
    required this.title,
    required this.description,
    required this.questions,
  });

  final String id;
  final String title;
  final String description;
  final List<QuizQuestion> questions;
}
