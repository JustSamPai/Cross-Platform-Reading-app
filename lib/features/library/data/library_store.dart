import 'dart:typed_data';

import 'package:hive/hive.dart';

import '../../../core/storage/reading_storage.dart';
import '../models/document_note.dart';
import '../models/reading_document.dart';

class LibraryStore {
  LibraryStore({Box<dynamic>? box}) : _box = box ?? ReadingStorage.box;

  static const _documentsKey = 'library.documents';
  static const _notesPrefix = 'library.notes.';

  final Box<dynamic> _box;

  List<ReadingDocument> documents() {
    final raw = _box.get(_documentsKey);
    if (raw is! List) {
      return const [];
    }

    return raw
        .whereType<Map<dynamic, dynamic>>()
        .map(ReadingDocument.fromMap)
        .toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
  }

  List<ReadingDocument> addDocument(ReadingDocument document) {
    final docs = documents().toList();
    final alreadyImported = docs.any(
      (stored) =>
          (document.filePath != null && stored.filePath == document.filePath) ||
          (document.filePath == null &&
              stored.title == document.title &&
              stored.type == document.type),
    );

    if (!alreadyImported) {
      docs.insert(0, document);
      _saveDocuments(docs);
    }

    return documents();
  }

  List<ReadingDocument> deleteDocument(String id) {
    final docs = documents().toList()
      ..removeWhere((document) => document.id == id);
    _saveDocuments(docs);
    _box.delete(_notesKey(id));
    return documents();
  }

  ReadingDocument? updateDocumentBytes(String id, Uint8List bytes) {
    final docs = documents().toList();
    final index = docs.indexWhere((document) => document.id == id);
    if (index == -1) {
      return null;
    }

    docs[index] = docs[index].copyWith(bytes: bytes);
    _saveDocuments(docs);
    return docs[index];
  }

  ReadingDocument? updateDocumentProgress(
    String id, {
    required int pageNumber,
    int? pageCount,
    String? epubCfi,
  }) {
    final docs = documents().toList();
    final index = docs.indexWhere((document) => document.id == id);
    if (index == -1) {
      return null;
    }

    docs[index] = docs[index].copyWith(
      lastPageNumber: pageNumber,
      pageCount: pageCount,
      lastOpenedAt: DateTime.now(),
      epubCfi: epubCfi,
    );
    _saveDocuments(docs);
    return docs[index];
  }

  ReadingDocument? updateManualBookProgress(
    String id, {
    required int currentPage,
    required int totalPages,
  }) {
    final docs = documents().toList();
    final index = docs.indexWhere((document) => document.id == id);
    if (index == -1) {
      return null;
    }

    docs[index] = docs[index].copyWith(
      lastPageNumber: currentPage.clamp(0, totalPages).toInt(),
      pageCount: totalPages,
      lastOpenedAt: DateTime.now(),
    );
    _saveDocuments(docs);
    return docs[index];
  }

  List<DocumentNote> notesFor(String documentId) {
    final raw = _box.get(_notesKey(documentId));
    if (raw is! List) {
      return const [];
    }

    return raw
        .whereType<Map<dynamic, dynamic>>()
        .map(DocumentNote.fromMap)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<DocumentNote> addNote(DocumentNote note) {
    final notes = notesFor(note.documentId).toList()..insert(0, note);
    _saveNotes(note.documentId, notes);
    return notesFor(note.documentId);
  }

  List<DocumentNote> deleteNote(String documentId, String noteId) {
    final notes = notesFor(documentId).toList()
      ..removeWhere((note) => note.id == noteId);
    _saveNotes(documentId, notes);
    return notesFor(documentId);
  }

  void _saveDocuments(List<ReadingDocument> documents) {
    _box.put(
      _documentsKey,
      documents.map((document) => document.toMap()).toList(),
    );
  }

  void _saveNotes(String documentId, List<DocumentNote> notes) {
    _box.put(
      _notesKey(documentId),
      notes.map((note) => note.toMap()).toList(),
    );
  }

  String _notesKey(String documentId) => '$_notesPrefix$documentId';
}
