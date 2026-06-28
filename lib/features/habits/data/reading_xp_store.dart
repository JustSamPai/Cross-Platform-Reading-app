import 'package:hive/hive.dart';

import '../../../core/storage/reading_storage.dart';

class ReadingXpStore {
  ReadingXpStore({Box<dynamic>? box}) : _box = box ?? ReadingStorage.box;

  static const xpPerPage = 1;
  static const fifthPageBonusXp = 5;
  static const tenPageBonusXp = 10;
  static const bookCompletionBonusXp = 25;

  static const _currentXpKey = 'readingXp.currentXp';
  static const _currentLevelKey = 'readingXp.currentLevel';
  static const _xpNeededKey = 'readingXp.xpNeededForNextLevel';
  static const _totalXpKey = 'readingXp.totalXp';
  static const _pagesReadKey = 'readingXp.pagesRead';
  static const _fifthPageBonusesKey = 'readingXp.fifthPageBonuses';
  static const _tenPageBonusesKey = 'readingXp.tenPageBonuses';
  static const _completedBooksKey = 'readingXp.completedBooks';
  static const _documentPagesPrefix = 'readingXp.documentPages.';

  final Box<dynamic> _box;

  ReadingXpProgress load() {
    return ReadingXpProgress(
      currentXp: _readInt(_currentXpKey),
      currentLevel: _readInt(_currentLevelKey, fallback: 1),
      xpNeededForNextLevel: _readInt(
        _xpNeededKey,
        fallback: _xpNeededForLevel(1),
      ),
      totalXp: _readInt(_totalXpKey),
      pagesRead: _readInt(_pagesReadKey),
      fifthPageBonuses: _readInt(_fifthPageBonusesKey),
      tenPageBonuses: _readInt(_tenPageBonusesKey),
      completedBookIds: _readStringSet(_completedBooksKey),
    );
  }

  ReadingXpReward recordPagesThrough({
    required String documentId,
    required int completedPages,
    required int totalPages,
  }) {
    if (completedPages <= 0 || totalPages <= 0) {
      return ReadingXpReward.none(load());
    }

    final cappedPages = completedPages.clamp(0, totalPages).toInt();
    final pages = {
      for (var page = 1; page <= cappedPages; page++) 'page:$page': page,
    };
    return _recordPages(
      documentId: documentId,
      pages: pages,
      totalPages: totalPages,
    );
  }

  ReadingXpReward recordPage({
    required String documentId,
    required String pageId,
    required int totalPages,
    int? pageNumber,
  }) {
    final trimmedPageId = pageId.trim();
    if (trimmedPageId.isEmpty || totalPages <= 0) {
      return ReadingXpReward.none(load());
    }

    return _recordPages(
      documentId: documentId,
      pages: {trimmedPageId: pageNumber},
      totalPages: totalPages,
    );
  }

  ReadingXpReward _recordPages({
    required String documentId,
    required Map<String, int?> pages,
    required int totalPages,
  }) {
    final storedPages = _readStringSet(_documentPagesKey(documentId));
    final newPages = Map<String, int?>.from(pages)
      ..removeWhere((pageId, pageNumber) => storedPages.contains(pageId));
    final updatedPages = {...storedPages, ...pages.keys};
    final newlyReadPages = updatedPages.length - storedPages.length;
    final previousProgress = load();
    final nextPagesRead = previousProgress.pagesRead + newlyReadPages;
    final newTenPageBonuses = newPages.values.where((pageNumber) {
      return pageNumber != null && pageNumber > 0 && pageNumber % 10 == 0;
    }).length;
    final newFifthPageBonuses = newPages.values.where((pageNumber) {
      return pageNumber != null &&
          pageNumber > 0 &&
          pageNumber % 5 == 0 &&
          pageNumber % 10 != 0;
    }).length;

    final completedBookIds = {...previousProgress.completedBookIds};
    final completedNow = totalPages > 0 &&
        updatedPages.length >= totalPages &&
        completedBookIds.add(documentId);

    final pageXp = newlyReadPages * xpPerPage;
    final milestoneXp = (newFifthPageBonuses * fifthPageBonusXp) +
        (newTenPageBonuses * tenPageBonusXp);
    final completionXp = completedNow ? bookCompletionBonusXp : 0;
    final xpEarned = pageXp + milestoneXp + completionXp;

    if (newlyReadPages > 0) {
      _box.put(_documentPagesKey(documentId), updatedPages.toList());
      _box.put(_pagesReadKey, nextPagesRead);
    }
    if (newTenPageBonuses > 0) {
      _box.put(
        _tenPageBonusesKey,
        previousProgress.tenPageBonuses + newTenPageBonuses,
      );
    }
    if (newFifthPageBonuses > 0) {
      _box.put(
        _fifthPageBonusesKey,
        previousProgress.fifthPageBonuses + newFifthPageBonuses,
      );
    }
    if (completedNow) {
      _box.put(_completedBooksKey, completedBookIds.toList());
    }

    final progress = _awardXp(xpEarned);
    return ReadingXpReward(
      xpEarned: xpEarned,
      pageXp: pageXp,
      milestoneXp: milestoneXp,
      completionXp: completionXp,
      newlyReadPages: newlyReadPages,
      progress: progress,
    );
  }

  ReadingXpProgress _awardXp(int amount) {
    if (amount <= 0) {
      return load();
    }

    final previous = load();
    var currentXp = previous.currentXp + amount;
    var currentLevel = previous.currentLevel;
    var xpNeededForNextLevel = previous.xpNeededForNextLevel;

    while (currentXp >= xpNeededForNextLevel) {
      currentXp -= xpNeededForNextLevel;
      currentLevel++;
      xpNeededForNextLevel = _xpNeededForLevel(currentLevel);
    }

    _box.put(_currentXpKey, currentXp);
    _box.put(_currentLevelKey, currentLevel);
    _box.put(_xpNeededKey, xpNeededForNextLevel);
    _box.put(_totalXpKey, previous.totalXp + amount);
    return load();
  }

  void reset() {
    for (final key in _box.keys.toList()) {
      if (key.toString().startsWith('readingXp.')) {
        _box.delete(key);
      }
    }
  }

  int _readInt(String key, {int fallback = 0}) {
    return (_box.get(key) as num?)?.toInt() ?? fallback;
  }

  Set<String> _readStringSet(String key) {
    return (_box.get(key) as List?)?.map((value) => value.toString()).toSet() ??
        <String>{};
  }

  int _xpNeededForLevel(int level) => 100 + ((level - 1) * 50);

  String _documentPagesKey(String documentId) =>
      '$_documentPagesPrefix$documentId';
}

class ReadingXpProgress {
  const ReadingXpProgress({
    required this.currentXp,
    required this.currentLevel,
    required this.xpNeededForNextLevel,
    required this.totalXp,
    required this.pagesRead,
    required this.fifthPageBonuses,
    required this.tenPageBonuses,
    required this.completedBookIds,
  });

  final int currentXp;
  final int currentLevel;
  final int xpNeededForNextLevel;
  final int totalXp;
  final int pagesRead;
  final int fifthPageBonuses;
  final int tenPageBonuses;
  final Set<String> completedBookIds;

  int get completedBooks => completedBookIds.length;

  String? get readingTitle => pagesRead >= 100 ? 'Fan' : null;

  double get levelProgress {
    if (xpNeededForNextLevel <= 0) {
      return 0;
    }
    return (currentXp / xpNeededForNextLevel).clamp(0, 1).toDouble();
  }
}

class ReadingXpReward {
  const ReadingXpReward({
    required this.xpEarned,
    required this.pageXp,
    required this.milestoneXp,
    required this.completionXp,
    required this.newlyReadPages,
    required this.progress,
  });

  factory ReadingXpReward.none(ReadingXpProgress progress) {
    return ReadingXpReward(
      xpEarned: 0,
      pageXp: 0,
      milestoneXp: 0,
      completionXp: 0,
      newlyReadPages: 0,
      progress: progress,
    );
  }

  final int xpEarned;
  final int pageXp;
  final int milestoneXp;
  final int completionXp;
  final int newlyReadPages;
  final ReadingXpProgress progress;
}
