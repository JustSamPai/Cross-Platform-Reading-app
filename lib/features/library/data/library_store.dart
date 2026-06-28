import 'dart:typed_data';

import 'package:hive/hive.dart';

import '../../../core/storage/reading_storage.dart';
import '../../habits/data/reading_xp_store.dart';
import '../models/document_note.dart';
import '../models/reading_document.dart';

class LibraryStore {
  LibraryStore({Box<dynamic>? box, ReadingXpStore? readingXpStore})
      : _box = box ?? ReadingStorage.box,
        _readingXpStore =
            readingXpStore ?? ReadingXpStore(box: box ?? ReadingStorage.box);

  static const _documentsKey = 'library.documents';
  static const _notesPrefix = 'library.notes.';
  static const minimumChapterReadSeconds = 30;

  final Box<dynamic> _box;
  final ReadingXpStore _readingXpStore;

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

  List<ReadingDocument> readingHistory() {
    return documents()
        .where((document) => document.lastOpenedAt != null)
        .toList()
      ..sort((a, b) {
        return b.lastOpenedAt!.compareTo(a.lastOpenedAt!);
      });
  }

  List<ReadingDocument> addDocument(ReadingDocument document) {
    final docs = documents().toList();
    final alreadyImported = docs.any(
      (stored) =>
          (document.filePath != null && stored.filePath == document.filePath) ||
          (document.sourceUrl != null &&
              stored.sourceUrl == document.sourceUrl) ||
          (document.filePath == null &&
              document.sourceUrl == null &&
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
    bool awardReadingXp = true,
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
    if (awardReadingXp) {
      _readingXpStore.recordPagesThrough(
        documentId: id,
        completedPages: pageNumber,
        totalPages: docs[index].pageCount,
      );
    }
    return docs[index];
  }

  void markDocumentPageRead(
    String id, {
    required int pageNumber,
    required int pageCount,
  }) {
    if (pageNumber <= 0 || pageCount <= 0) {
      return;
    }
    _readingXpStore.recordPage(
      documentId: id,
      pageId: 'page:$pageNumber',
      totalPages: pageCount,
      pageNumber: pageNumber,
    );
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
    _readingXpStore.recordPagesThrough(
      documentId: id,
      completedPages: docs[index].lastPageNumber,
      totalPages: totalPages,
    );
    return docs[index];
  }

  ReadingDocument? updateDocumentSourceText(
    String id, {
    required String sourceText,
  }) {
    final docs = documents().toList();
    final index = docs.indexWhere((document) => document.id == id);
    if (index == -1) {
      return null;
    }

    docs[index] = docs[index].copyWith(
      sourceText: sourceText,
      lastOpenedAt: DateTime.now(),
    );
    _saveDocuments(docs);
    return docs[index];
  }

  ReadingDocument? markChapterRead(
    String id, {
    required String chapterUrl,
    required String chapterTitle,
    required int chapterNumber,
    required int chapterCount,
  }) {
    final docs = documents().toList();
    final index = docs.indexWhere((document) => document.id == id);
    if (index == -1) {
      return null;
    }

    final readChapterUrls = {
      ...docs[index].readChapterUrls,
      chapterUrl,
    }.toList();

    docs[index] = docs[index].copyWith(
      lastReadChapterUrl: chapterUrl,
      lastReadChapterTitle: chapterTitle,
      readChapterUrls: readChapterUrls,
      lastPageNumber: chapterNumber.clamp(0, chapterCount).toInt(),
      pageCount: chapterCount,
      lastOpenedAt: DateTime.now(),
    );
    _saveDocuments(docs);
    _readingXpStore.recordPage(
      documentId: id,
      pageId: 'chapter:$chapterUrl',
      totalPages: chapterCount,
      pageNumber: chapterNumber,
    );
    return docs[index];
  }

  ReadingDocument? recordChapterReadingTime(
    String id, {
    required String chapterUrl,
    required String chapterTitle,
    required int chapterNumber,
    required int chapterCount,
    required int elapsedSeconds,
    int? requiredReadSeconds,
  }) {
    final docs = documents().toList();
    final index = docs.indexWhere((document) => document.id == id);
    if (index == -1) {
      return null;
    }

    final currentDocument = docs[index];
    final chapterReadingSeconds = {
      ...currentDocument.chapterReadingSeconds,
    };
    final previousChapterSeconds = chapterReadingSeconds[chapterUrl] ?? 0;
    final addedSeconds = elapsedSeconds.clamp(0, 3600).toInt();
    final updatedChapterSeconds = previousChapterSeconds + addedSeconds;
    chapterReadingSeconds[chapterUrl] = updatedChapterSeconds;

    final readChapterUrls = {...currentDocument.readChapterUrls};
    final secondsRequired = requiredReadSeconds ?? minimumChapterReadSeconds;

    final qualifiedNow =
      updatedChapterSeconds >= secondsRequired &&
      readChapterUrls.add(chapterUrl);

    docs[index] = currentDocument.copyWith(
      lastReadChapterUrl: chapterUrl,
      lastReadChapterTitle: chapterTitle,
      readChapterUrls: readChapterUrls.toList(),
      lastPageNumber: chapterNumber.clamp(0, chapterCount).toInt(),
      pageCount: chapterCount,
      lastOpenedAt: DateTime.now(),
      readingSeconds: currentDocument.readingSeconds + addedSeconds,
      chapterReadingSeconds: chapterReadingSeconds,
    );
    _saveDocuments(docs);

    if (qualifiedNow) {
      _readingXpStore.recordPage(
        documentId: id,
        pageId: 'chapter:$chapterUrl',
        totalPages: chapterCount,
        pageNumber: chapterNumber,
      );
    }
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
