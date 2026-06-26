import 'dart:typed_data';

import 'package:path/path.dart' as path;

enum ReadingDocumentType {
  pdf,
  epub,
  book,
  other;

  String get label {
    return switch (this) {
      ReadingDocumentType.pdf => 'PDF',
      ReadingDocumentType.epub => 'EPUB',
      ReadingDocumentType.book => 'Book',
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

  bool get canOpenInApp =>
      bytes != null &&
      (type == ReadingDocumentType.pdf || type == ReadingDocumentType.epub);

  double get progress {
    if (pageCount <= 0) {
      return 0;
    }
    return (lastPageNumber / pageCount).clamp(0, 1).toDouble();
  }

  int get progressPercent => (progress * 100).round();

  String get progressLabel {
    if (pageCount <= 0) {
      return type == ReadingDocumentType.book
          ? 'No pages logged'
          : 'Not started';
    }

    return 'Page $lastPageNumber of $pageCount';
  }

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
}
