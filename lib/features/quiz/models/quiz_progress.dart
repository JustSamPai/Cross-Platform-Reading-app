class QuizProgress {
  const QuizProgress({
    required this.currentXp,
    required this.currentLevel,
    required this.xpNeededForNextLevel,
    required this.completedDeckIds,
  });

  final int currentXp;
  final int currentLevel;
  final int xpNeededForNextLevel;
  final Set<String> completedDeckIds;

  double get levelProgress {
    if (xpNeededForNextLevel == 0) {
      return 0;
    }

    return (currentXp / xpNeededForNextLevel).clamp(0, 1).toDouble();
  }

  bool isDeckCompleted(String deckId) {
    return completedDeckIds.contains(deckId);
  }
}

class QuizCompletion {
  const QuizCompletion({
    required this.correctAnswers,
    required this.totalQuestions,
  });

  final int correctAnswers;
  final int totalQuestions;

  double get percentage {
    if (totalQuestions == 0) {
      return 0;
    }

    return (correctAnswers / totalQuestions) * 100;
  }
}

class QuizReward {
  const QuizReward({
    required this.percentage,
    required this.xpEarned,
    required this.currentLevel,
  });

  final double percentage;
  final int xpEarned;
  final int currentLevel;
}
