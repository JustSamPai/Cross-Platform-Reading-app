class QuizQuestion {
  QuizQuestion({
    required this.prompt,
    required this.answers,
    required this.correctIndex,
  })  : assert(answers.length > 1),
        assert(correctIndex >= 0),
        assert(correctIndex < answers.length);

  final String prompt;
  final List<String> answers;
  final int correctIndex;

  String get correctAnswer => answers[correctIndex];

  bool isCorrect(int selectedIndex) {
    return selectedIndex == correctIndex;
  }
}
