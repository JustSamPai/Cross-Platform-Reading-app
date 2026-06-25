import 'dart:typed_data';

import 'package:path/path.dart' as path;

enum ReadingDocumentType {
  pdf,
  epub,
  unknown;

  String get label {
    return switch (this) {
      ReadingDocumentType.pdf => 'PDF',
      ReadingDocumentType.epub => 'EPUB',
      ReadingDocumentType.unknown => 'Document',
    };
  }

  static ReadingDocumentType fromFileName(String fileName) {
    final extension = path.extension(fileName).toLowerCase();
    return switch (extension) {
      '.pdf' => ReadingDocumentType.pdf,
      '.epub' => ReadingDocumentType.epub,
      _ => ReadingDocumentType.unknown,
    };
  }
}

class ReadingDocument {
  const ReadingDocument({
    required this.id,
    required this.title,
    required this.type,
    required this.addedAt,
    this.lastPageNumber = 1,
    this.lastOpenedAt,
    this.bytes,
    this.filePath,
  });

  final String id;
  final String title;
  final ReadingDocumentType type;
  final DateTime addedAt;
  final int lastPageNumber;
  final DateTime? lastOpenedAt;
  final Uint8List? bytes;
  final String? filePath;

  bool get canOpenInApp => bytes != null && type == ReadingDocumentType.pdf;

  ReadingDocument copyWith({
    String? id,
    String? title,
    ReadingDocumentType? type,
    DateTime? addedAt,
    int? lastPageNumber,
    DateTime? lastOpenedAt,
    Uint8List? bytes,
    String? filePath,
  }) {
    return ReadingDocument(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      addedAt: addedAt ?? this.addedAt,
      lastPageNumber: lastPageNumber ?? this.lastPageNumber,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
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
      'lastPageNumber': lastPageNumber,
      'lastOpenedAt': lastOpenedAt?.toIso8601String(),
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
        orElse: () => ReadingDocumentType.unknown,
      ),
      addedAt:
          DateTime.tryParse(map['addedAt'] as String? ?? '') ?? DateTime.now(),
      lastPageNumber: (map['lastPageNumber'] as num?)?.toInt() ?? 1,
      lastOpenedAt: DateTime.tryParse(map['lastOpenedAt'] as String? ?? ''),
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
}
