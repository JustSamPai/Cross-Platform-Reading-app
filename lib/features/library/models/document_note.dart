class DocumentNote {
  const DocumentNote({
    required this.id,
    required this.documentId,
    required this.pageNumber,
    required this.selectedText,
    required this.comment,
    required this.createdAt,
  });

  final String id;
  final String documentId;
  final int pageNumber;
  final String selectedText;
  final String comment;
  final DateTime createdAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'documentId': documentId,
      'pageNumber': pageNumber,
      'selectedText': selectedText,
      'comment': comment,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory DocumentNote.fromMap(Map<dynamic, dynamic> map) {
    return DocumentNote(
      id: map['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      documentId: map['documentId'] as String? ?? '',
      pageNumber: (map['pageNumber'] as num?)?.toInt() ?? 1,
      selectedText: map['selectedText'] as String? ?? '',
      comment: map['comment'] as String? ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  factory DocumentNote.create({
    required String documentId,
    required int pageNumber,
    required String selectedText,
    required String comment,
  }) {
    return DocumentNote(
      id: '${DateTime.now().microsecondsSinceEpoch}-$documentId',
      documentId: documentId,
      pageNumber: pageNumber,
      selectedText: selectedText,
      comment: comment,
      createdAt: DateTime.now(),
    );
  }
}
