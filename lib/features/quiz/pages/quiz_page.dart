import 'package:flutter/material.dart';

import '../models/quiz_question.dart';

class QuizPage extends StatefulWidget {
  const QuizPage({super.key});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  static const question = QuizQuestion(
    prompt: 'What is the main benefit of reading notes after a session?',
    answers: [
      'It improves recall',
      'It makes books shorter',
      'It replaces practice',
      'It removes the need for quizzes',
    ],
    correctIndex: 0,
  );

  int? selectedIndex;

  @override
  Widget build(BuildContext context) {
    final answered = selectedIndex != null;
    final correct = answered && question.isCorrect(selectedIndex!);

    return Scaffold(
      appBar: AppBar(title: const Text('Reading Quiz')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            question.prompt,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          for (var index = 0; index < question.answers.length; index++)
            Card(
              child: RadioListTile<int>(
                value: index,
                groupValue: selectedIndex,
                onChanged: (value) {
                  setState(() => selectedIndex = value);
                },
                title: Text(question.answers[index]),
              ),
            ),
          const SizedBox(height: 16),
          if (answered)
            Text(
              correct ? 'Correct' : 'Try again',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: correct ? Colors.green : Colors.red,
                  ),
            ),
        ],
      ),
    );
  }
}
