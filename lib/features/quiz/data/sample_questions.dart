import '../models/quiz_question.dart';
import '../models/quiz_deck.dart';

final sampleQuestions = [
  QuizQuestion(
    prompt:
        'What is the main benefit of reviewing notes after a reading session?',
    answers: [
      'It improves recall',
      'It makes books shorter',
      'It replaces practice',
      'It removes the need for quizzes',
    ],
    correctIndex: 0,
  ),
  QuizQuestion(
    prompt: 'Which habit best supports long-term comprehension?',
    answers: [
      'Skimming once and moving on',
      'Returning to important ideas over time',
      'Only reading when a deadline appears',
      'Tracking page count without notes',
    ],
    correctIndex: 1,
  ),
];

final sampleQuizDecks = [
  QuizDeck(
    id: 'reading-recall',
    title: 'Quiz 1',
    description: 'Reading recall and note review',
    questions: sampleQuestions,
  ),
  QuizDeck(
    id: 'general-knowledge',
    title: 'Quiz 2',
    description: 'General knowledge warm-up',
    questions: [
      QuizQuestion(
        prompt: 'What is the capital of France?',
        answers: const ['Paris', 'London', 'Berlin', 'Rome'],
        correctIndex: 0,
      ),
      QuizQuestion(
        prompt: 'What is the largest ocean in the world?',
        answers: const [
          'Atlantic Ocean',
          'Indian Ocean',
          'Pacific Ocean',
          'Arctic Ocean',
        ],
        correctIndex: 2,
      ),
      QuizQuestion(
        prompt: 'What is the symbol for gold on the periodic table?',
        answers: const ['Ag', 'Hg', 'Au', 'Pb'],
        correctIndex: 2,
      ),
    ],
  ),
];
