import 'package:flutter/material.dart';

import '../models/quiz_deck.dart';
import '../models/quiz_progress.dart';

class QuizViewPage extends StatefulWidget {
  const QuizViewPage({
    required this.deck,
    super.key,
  });

  final QuizDeck deck;

  @override
  State<QuizViewPage> createState() => _QuizViewPageState();
}

class _QuizViewPageState extends State<QuizViewPage> {
  int currentQuestionIndex = 0;
  int correctAnswers = 0;
  final selectedAnswers = <int>[];

  @override
  Widget build(BuildContext context) {
    final question = widget.deck.questions[currentQuestionIndex];
    final progress = (currentQuestionIndex + 1) / widget.deck.questions.length;

    return Scaffold(
      appBar: AppBar(title: Text(widget.deck.title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Question ${currentQuestionIndex + 1}',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: progress,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                question.prompt,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              for (var index = 0; index < question.answers.length; index++)
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(question.answers[index]),
                    trailing: const Icon(Icons.arrow_forward),
                    onTap: () => _submitAnswer(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _submitAnswer(int selectedIndex) {
    final question = widget.deck.questions[currentQuestionIndex];
    selectedAnswers.add(selectedIndex);

    if (question.isCorrect(selectedIndex)) {
      correctAnswers++;
    }

    if (currentQuestionIndex < widget.deck.questions.length - 1) {
      setState(() => currentQuestionIndex++);
      return;
    }

    Navigator.pop(
      context,
      QuizCompletion(
        correctAnswers: correctAnswers,
        totalQuestions: widget.deck.questions.length,
      ),
    );
  }
}
