import 'package:flutter/material.dart';

import '../../../core/widgets/page_frame.dart';
import '../data/quiz_progress_store.dart';
import '../data/sample_questions.dart';
import '../models/quiz_deck.dart';
import '../models/quiz_progress.dart';
import 'quiz_view_page.dart';

class QuizPage extends StatefulWidget {
  const QuizPage({super.key});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final store = QuizProgressStore();
  late QuizProgress progress;
  QuizReward? lastReward;

  @override
  void initState() {
    super.initState();
    progress = store.load();
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Review quiz',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
              ),
              OutlinedButton.icon(
                onPressed: _resetProgress,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ProgressCard(progress: progress, reward: lastReward),
          const SizedBox(height: 28),
          Text(
            'Quizzes',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          for (final deck in sampleQuizDecks)
            _QuizDeckCard(
              deck: deck,
              completed: progress.isDeckCompleted(deck.id),
              onStart: () => _startQuiz(deck),
            ),
        ],
      ),
    );
  }

  Future<void> _startQuiz(QuizDeck deck) async {
    if (progress.isDeckCompleted(deck.id)) {
      return;
    }

    final completion = await Navigator.push<QuizCompletion>(
      context,
      MaterialPageRoute(
        builder: (context) => QuizViewPage(deck: deck),
      ),
    );

    if (completion == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      lastReward = store.completeDeck(deck, completion);
      progress = store.load();
    });
  }

  void _resetProgress() {
    store.reset();
    setState(() {
      progress = store.load();
      lastReward = null;
    });
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.progress,
    required this.reward,
  });

  final QuizProgress progress;
  final QuizReward? reward;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Level ${progress.currentLevel}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text(
                    '${progress.currentXp} / ${progress.xpNeededForNextLevel} XP'),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: progress.levelProgress,
              ),
            ),
            if (reward != null) ...[
              const SizedBox(height: 12),
              Text(
                'Last score: ${reward!.percentage.toStringAsFixed(0)}% - ${reward!.xpEarned} XP earned',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuizDeckCard extends StatelessWidget {
  const _QuizDeckCard({
    required this.deck,
    required this.completed,
    required this.onStart,
  });

  final QuizDeck deck;
  final bool completed;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(completed ? Icons.check_circle : Icons.quiz_outlined),
        title: Text(deck.title),
        subtitle: Text(deck.description),
        trailing: FilledButton(
          onPressed: completed ? null : onStart,
          child: Text(completed ? 'Done' : 'Start'),
        ),
      ),
    );
  }
}
