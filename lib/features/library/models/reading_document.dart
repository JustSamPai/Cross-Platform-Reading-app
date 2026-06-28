import 'dart:typed_data';

import 'package:path/path.dart' as path;

enum ReadingDocumentType {
  pdf,
  epub,
  book,
  webNovel,
  other;

  String get label {
    return switch (this) {
      ReadingDocumentType.pdf => 'PDF',
      ReadingDocumentType.epub => 'EPUB',
      ReadingDocumentType.book => 'Book',
      ReadingDocumentType.webNovel => 'Web Novel',
      ReadingDocumentType.other => 'File',
    };
  }

  static ReadingDocumentType fromFileName(String fileName) {
    final extension = path.extension(fileName).toLowerCase();
    return switch (extension) {
      '.pdf' => ReadingDocumentType.pdf,
      '.epub' => ReadingDocumentType.epub,
      _ => ReadingDocumentType.other,
    };
  }
}

enum NovelReadingTier {
  none,
  green,
  blue,
  gold,
  purple,
}

class ReadingDocument {
  const ReadingDocument({
    required this.id,
    required this.title,
    required this.type,
    required this.addedAt,
    this.author,
    this.lastPageNumber = 1,
    this.pageCount = 0,
    this.lastOpenedAt,
    this.epubCfi,
    this.bytes,
    this.filePath,
    this.sourceUrl,
    this.sourceName,
    this.sourceText,
    this.coverUrl,
    this.lastReadChapterUrl,
    this.lastReadChapterTitle,
    this.readChapterUrls = const [],
    this.readingSeconds = 0,
    this.chapterReadingSeconds = const {},
  });

  final String id;
  final String title;
  final ReadingDocumentType type;
  final DateTime addedAt;
  final String? author;
  final int lastPageNumber;
  final int pageCount;
  final DateTime? lastOpenedAt;
  final String? epubCfi;
  final Uint8List? bytes;
  final String? filePath;
  final String? sourceUrl;
  final String? sourceName;
  final String? sourceText;
  final String? coverUrl;
  final String? lastReadChapterUrl;
  final String? lastReadChapterTitle;
  final List<String> readChapterUrls;
  final int readingSeconds;
  final Map<String, int> chapterReadingSeconds;

  bool get canOpenInApp =>
      (bytes != null &&
          (type == ReadingDocumentType.pdf ||
              type == ReadingDocumentType.epub)) ||
      (type == ReadingDocumentType.webNovel &&
          ((sourceUrl?.isNotEmpty ?? false) ||
              (sourceText?.isNotEmpty ?? false)));

  double get progress {
    if (pageCount <= 0) {
      return 0;
    }
    if (type == ReadingDocumentType.webNovel && _tracksWebChapters) {
      return (readChapterUrls.length / pageCount).clamp(0, 1).toDouble();
    }
    return (lastPageNumber / pageCount).clamp(0, 1).toDouble();
  }

  int get progressPercent => (progress * 100).round();

  NovelReadingTier get novelReadingTier {
    if (type != ReadingDocumentType.webNovel || readChapterUrls.isEmpty) {
      return NovelReadingTier.none;
    }

    final chaptersRead = readChapterUrls.length;
    if (chaptersRead >= 100) {
      return NovelReadingTier.purple;
    }
    if (chaptersRead >= 50) {
      return NovelReadingTier.gold;
    }
    if (chaptersRead >= 10) {
      return NovelReadingTier.blue;
    }
    return NovelReadingTier.green;
  }

  int? get nextNovelTierChapterTarget {
    return switch (novelReadingTier) {
      NovelReadingTier.none => 1,
      NovelReadingTier.green => 10,
      NovelReadingTier.blue => 50,
      NovelReadingTier.gold => 100,
      NovelReadingTier.purple => null,
    };
  }

  int get chaptersToNextNovelTier {
    final target = nextNovelTierChapterTarget;
    if (target == null) {
      return 0;
    }
    return (target - readChapterUrls.length).clamp(0, target).toInt();
  }

  int readingSecondsToNextNovelTier({required int secondsPerChapter}) {
    final chaptersNeeded = chaptersToNextNovelTier;
    if (chaptersNeeded == 0) {
      return 0;
    }

    final partialChapterSeconds = chapterReadingSeconds.entries
        .where((entry) => !readChapterUrls.contains(entry.key))
        .map((entry) => entry.value.clamp(0, secondsPerChapter).toInt())
        .toList()
      ..sort((a, b) => b.compareTo(a));
    var remainingSeconds = 0;
    for (var index = 0; index < chaptersNeeded; index++) {
      final accumulated = index < partialChapterSeconds.length
          ? partialChapterSeconds[index]
          : 0;
      remainingSeconds += secondsPerChapter - accumulated;
    }
    return remainingSeconds;
  }

  String get progressLabel {
    if (pageCount <= 0) {
      return switch (type) {
        ReadingDocumentType.book => 'No pages logged',
        ReadingDocumentType.webNovel =>
          sourceName == null ? 'Saved source' : 'Saved from $sourceName',
        _ => 'Not started',
      };
    }

    if (type == ReadingDocumentType.webNovel && _tracksWebChapters) {
      return '${readChapterUrls.length} of $pageCount chapters read';
    }

    if (type == ReadingDocumentType.webNovel && pageCount == 1) {
      return lastPageNumber >= 1 ? 'Read' : 'Unread';
    }

    return 'Page $lastPageNumber of $pageCount';
  }

  bool get _tracksWebChapters =>
      lastReadChapterUrl != null || readChapterUrls.isNotEmpty || pageCount > 1;

  ReadingDocument copyWith({
    String? id,
    String? title,
    ReadingDocumentType? type,
    DateTime? addedAt,
    String? author,
    int? lastPageNumber,
    int? pageCount,
    DateTime? lastOpenedAt,
    String? epubCfi,
    Uint8List? bytes,
    String? filePath,
    String? sourceUrl,
    String? sourceName,
    String? sourceText,
    String? coverUrl,
    String? lastReadChapterUrl,
    String? lastReadChapterTitle,
    List<String>? readChapterUrls,
    int? readingSeconds,
    Map<String, int>? chapterReadingSeconds,
  }) {
    return ReadingDocument(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      addedAt: addedAt ?? this.addedAt,
      author: author ?? this.author,
      lastPageNumber: lastPageNumber ?? this.lastPageNumber,
      pageCount: pageCount ?? this.pageCount,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      epubCfi: epubCfi ?? this.epubCfi,
      bytes: bytes ?? this.bytes,
      filePath: filePath ?? this.filePath,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      sourceName: sourceName ?? this.sourceName,
      sourceText: sourceText ?? this.sourceText,
      coverUrl: coverUrl ?? this.coverUrl,
      lastReadChapterUrl: lastReadChapterUrl ?? this.lastReadChapterUrl,
      lastReadChapterTitle: lastReadChapterTitle ?? this.lastReadChapterTitle,
      readChapterUrls: readChapterUrls ?? this.readChapterUrls,
      readingSeconds: readingSeconds ?? this.readingSeconds,
      chapterReadingSeconds:
          chapterReadingSeconds ?? this.chapterReadingSeconds,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'type': type.name,
      'addedAt': addedAt.toIso8601String(),
      'author': author,
      'lastPageNumber': lastPageNumber,
      'pageCount': pageCount,
      'lastOpenedAt': lastOpenedAt?.toIso8601String(),
      'epubCfi': epubCfi,
      'bytes': bytes,
      'filePath': filePath,
      'sourceUrl': sourceUrl,
      'sourceName': sourceName,
      'sourceText': sourceText,
      'coverUrl': coverUrl,
      'lastReadChapterUrl': lastReadChapterUrl,
      'lastReadChapterTitle': lastReadChapterTitle,
      'readChapterUrls': readChapterUrls,
      'readingSeconds': readingSeconds,
      'chapterReadingSeconds': chapterReadingSeconds,
    };
  }

  factory ReadingDocument.fromMap(Map<dynamic, dynamic> map) {
    final rawBytes = map['bytes'];

    return ReadingDocument(
      id: map['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: map['title'] as String? ?? 'Untitled document',
      type: ReadingDocumentType.values.firstWhere(
        (type) => type.name == map['type'],
        orElse: () => ReadingDocumentType.other,
      ),
      addedAt:
          DateTime.tryParse(map['addedAt'] as String? ?? '') ?? DateTime.now(),
      author: map['author'] as String?,
      lastPageNumber: (map['lastPageNumber'] as num?)?.toInt() ?? 1,
      pageCount: (map['pageCount'] as num?)?.toInt() ?? 0,
      lastOpenedAt: DateTime.tryParse(map['lastOpenedAt'] as String? ?? ''),
      epubCfi: map['epubCfi'] as String?,
      bytes: rawBytes is Uint8List
          ? rawBytes
          : rawBytes is List<int>
              ? Uint8List.fromList(rawBytes)
              : null,
      filePath: map['filePath'] as String?,
      sourceUrl: map['sourceUrl'] as String?,
      sourceName: map['sourceName'] as String?,
      sourceText: map['sourceText'] as String?,
      coverUrl: map['coverUrl'] as String?,
      lastReadChapterUrl: map['lastReadChapterUrl'] as String?,
      lastReadChapterTitle: map['lastReadChapterTitle'] as String?,
      readChapterUrls:
          (map['readChapterUrls'] as List?)?.whereType<String>().toList() ??
              const [],
      readingSeconds: (map['readingSeconds'] as num?)?.toInt() ?? 0,
      chapterReadingSeconds:
          (map['chapterReadingSeconds'] as Map?)?.map<String, int>(
                (key, value) => MapEntry(
                  key.toString(),
                  (value as num?)?.toInt() ?? 0,
                ),
              ) ??
              const {},
    );
  }

  factory ReadingDocument.fromPickedFile({
    required String fileName,
    required Uint8List? bytes,
    required String? filePath,
  }) {
    return ReadingDocument(
      id: '${DateTime.now().microsecondsSinceEpoch}-$fileName',
      title: path.basenameWithoutExtension(fileName),
      type: ReadingDocumentType.fromFileName(fileName),
      addedAt: DateTime.now(),
      bytes: bytes,
      filePath: filePath,
    );
  }

  factory ReadingDocument.manualBook({
    required String title,
    required String author,
    required int totalPages,
    int currentPage = 0,
  }) {
    return ReadingDocument(
      id: '${DateTime.now().microsecondsSinceEpoch}-$title',
      title: title,
      author: author.isEmpty ? null : author,
      type: ReadingDocumentType.book,
      addedAt: DateTime.now(),
      lastPageNumber: currentPage.clamp(0, totalPages).toInt(),
      pageCount: totalPages,
    );
  }

  factory ReadingDocument.externalNovel({
    required String title,
    required String sourceUrl,
    required String sourceName,
    String author = '',
    String? description,
    String? coverUrl,
  }) {
    return ReadingDocument(
      id: '${DateTime.now().microsecondsSinceEpoch}-$title',
      title: title,
      author: author.isEmpty ? null : author,
      type: ReadingDocumentType.webNovel,
      addedAt: DateTime.now(),
      lastPageNumber: 0,
      pageCount: 1,
      sourceUrl: sourceUrl,
      sourceName: sourceName,
      sourceText: description,
      coverUrl: coverUrl,
    );
  }
}
