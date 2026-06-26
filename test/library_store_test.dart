import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_reading_portfolio_app/core/storage/reading_storage.dart';
import 'package:flutter_reading_portfolio_app/features/library/data/library_store.dart';
import 'package:flutter_reading_portfolio_app/features/library/models/document_note.dart';
import 'package:flutter_reading_portfolio_app/features/library/models/reading_document.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;
  late Box<dynamic> box;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('readflow_library_test_');
    Hive.init(tempDir.path);
    box = await Hive.openBox(ReadingStorage.boxName);
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('persists imported PDF bytes and notes', () {
    final store = LibraryStore(box: box);
    final document = ReadingDocument.fromPickedFile(
      fileName: 'notes.pdf',
      bytes: Uint8List.fromList([1, 2, 3]),
      filePath: null,
    );

    final documents = store.addDocument(document);
    final note = DocumentNote.create(
      documentId: documents.first.id,
      pageNumber: 2,
      selectedText: 'Important idea',
      comment: 'Review this later',
    );

    final notes = store.addNote(note);

    expect(documents.first.canOpenInApp, isTrue);
    expect(store.documents().first.bytes, [1, 2, 3]);
    expect(notes.single.comment, 'Review this later');
  });

  test('persists document reading progress', () {
    final store = LibraryStore(box: box);
    final document = ReadingDocument.fromPickedFile(
      fileName: 'chapter.pdf',
      bytes: Uint8List.fromList([4, 5, 6]),
      filePath: null,
    );

    final storedDocument = store.addDocument(document).first;
    store.updateDocumentProgress(
      storedDocument.id,
      pageNumber: 12,
      pageCount: 24,
    );

    final updatedDocument = store.documents().first;

    expect(updatedDocument.lastPageNumber, 12);
    expect(updatedDocument.pageCount, 24);
    expect(updatedDocument.progressPercent, 50);
    expect(updatedDocument.lastOpenedAt, isNotNull);
  });

  test('persists manual books', () {
    final store = LibraryStore(box: box);
    final book = ReadingDocument.manualBook(
      title: 'Designing Data-Intensive Applications',
      author: 'Martin Kleppmann',
      totalPages: 600,
      currentPage: 120,
    );

    final documents = store.addDocument(book);

    expect(documents.first.type, ReadingDocumentType.book);
    expect(documents.first.author, 'Martin Kleppmann');
    expect(documents.first.progressPercent, 20);
  });

  test('persists external web novels', () {
    final store = LibraryStore(box: box);
    final novel = ReadingDocument.externalNovel(
      title: 'A Remote Chapter',
      sourceUrl: 'https://example.com/novel/chapter-1',
      sourceName: 'Example Source',
      description: 'Opening scene',
    );

    final documents = store.addDocument(novel);
    final updated = store.updateDocumentSourceText(
      documents.first.id,
      sourceText: 'A readable chapter snapshot.',
    );

    expect(documents.first.type, ReadingDocumentType.webNovel);
    expect(documents.first.canOpenInApp, isTrue);
    expect(updated?.sourceText, contains('readable chapter'));
  });

  test('tracks web novel chapter history', () {
    final store = LibraryStore(box: box);
    final novel = ReadingDocument.externalNovel(
      title: 'A Remote Novel',
      sourceUrl: 'https://example.com/novel',
      sourceName: 'Example Source',
    );

    final document = store.addDocument(novel).first;
    store.markChapterRead(
      document.id,
      chapterUrl: 'https://example.com/novel/chapter-1',
      chapterTitle: 'Chapter 1',
      chapterNumber: 1,
      chapterCount: 3,
    );

    final updated = store.documents().first;

    expect(updated.lastReadChapterTitle, 'Chapter 1');
    expect(updated.readChapterUrls,
        contains('https://example.com/novel/chapter-1'));
    expect(updated.progressPercent, 33);
    expect(store.readingHistory().single.id, updated.id);
  });
}
