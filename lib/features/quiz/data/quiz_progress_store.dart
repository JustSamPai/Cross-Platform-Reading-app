import 'package:hive/hive.dart';

import '../../../core/storage/reading_storage.dart';
import '../models/quiz_deck.dart';
import '../models/quiz_progress.dart';

class QuizProgressStore {
  QuizProgressStore({Box<dynamic>? box}) : _box = box ?? ReadingStorage.box;

  static const _xpKey = 'quiz.currentXp';
  static const _levelKey = 'quiz.currentLevel';
  static const _xpNeededKey = 'quiz.xpNeededForNextLevel';
  static const _completedDecksKey = 'quiz.completedDecks';

  final Box<dynamic> _box;

  QuizProgress load() {
    return QuizProgress(
      currentXp: (_box.get(_xpKey) as num?)?.toInt() ?? 0,
      currentLevel: (_box.get(_levelKey) as num?)?.toInt() ?? 1,
      xpNeededForNextLevel: (_box.get(_xpNeededKey) as num?)?.toInt() ?? 10,
      completedDeckIds: (_box.get(_completedDecksKey) as List?)
              ?.map((id) => id.toString())
              .toSet() ??
          <String>{},
    );
  }

  QuizReward completeDeck(QuizDeck deck, QuizCompletion completion) {
    var progress = load();
    var currentXp = progress.currentXp;
    var currentLevel = progress.currentLevel;
    var xpNeededForNextLevel = progress.xpNeededForNextLevel;
    final completedDeckIds = {...progress.completedDeckIds, deck.id};

    final xpEarned = (completion.percentage / 10).floor();
    currentXp += xpEarned;

    while (currentXp >= xpNeededForNextLevel && xpNeededForNextLevel > 0) {
      currentXp -= xpNeededForNextLevel;
      currentLevel++;
      xpNeededForNextLevel = _xpNeededForLevel(currentLevel);
    }

    _box.put(_xpKey, currentXp);
    _box.put(_levelKey, currentLevel);
    _box.put(_xpNeededKey, xpNeededForNextLevel);
    _box.put(_completedDecksKey, completedDeckIds.toList());

    return QuizReward(
      percentage: completion.percentage,
      xpEarned: xpEarned,
      currentLevel: currentLevel,
    );
  }

  void reset() {
    _box.delete(_xpKey);
    _box.delete(_levelKey);
    _box.delete(_xpNeededKey);
    _box.delete(_completedDecksKey);
  }

  int _xpNeededForLevel(int level) {
    return ((level / 0.07) * (level / 0.07)).floor();
  }
}
