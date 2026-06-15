class QuizQuestion {
  const QuizQuestion({
    required this.prompt,
    required this.answers,
    required this.correctIndex,
  });

  final String prompt;
  final List<String> answers;
  final int correctIndex;

  bool isCorrect(int selectedIndex) {
    return selectedIndex == correctIndex;
  }
}
