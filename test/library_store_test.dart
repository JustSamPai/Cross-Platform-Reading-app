import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_reading_portfolio_app/core/storage/reading_storage.dart';
import 'package:flutter_reading_portfolio_app/features/habits/data/reading_xp_store.dart';
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
    expect(ReadingXpStore(box: box).load().pagesRead, 12);
    expect(ReadingXpStore(box: box).load().totalXp, 27);
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
    expect(ReadingXpStore(box: box).load().pagesRead, 1);
  });

  test('assigns saved novel colours from chapters read', () {
    final novel = ReadingDocument.externalNovel(
      title: 'Tiered Novel',
      sourceUrl: 'https://example.com/tiered-novel',
      sourceName: 'Example Source',
    );

    expect(
      novel.copyWith(readChapterUrls: ['chapter-1']).novelReadingTier,
      NovelReadingTier.green,
    );
    expect(
      novel
          .copyWith(
            readChapterUrls: List.generate(10, (index) => 'chapter-$index'),
          )
          .novelReadingTier,
      NovelReadingTier.blue,
    );
    expect(
      novel
          .copyWith(
            readChapterUrls: List.generate(50, (index) => 'chapter-$index'),
          )
          .novelReadingTier,
      NovelReadingTier.gold,
    );
    expect(
      novel
          .copyWith(
            readChapterUrls: List.generate(100, (index) => 'chapter-$index'),
          )
          .novelReadingTier,
      NovelReadingTier.purple,
    );
  });

  test('requires reading time before a source chapter counts', () {
    final store = LibraryStore(box: box);
    final novel = store
        .addDocument(
          ReadingDocument.externalNovel(
            title: 'Timed Novel',
            sourceUrl: 'https://example.com/timed-novel',
            sourceName: 'Example Source',
          ),
        )
        .first;

    final tooFast = store.recordChapterReadingTime(
      novel.id,
      chapterUrl: 'https://example.com/timed-novel/chapter-1',
      chapterTitle: 'Chapter 1',
      chapterNumber: 1,
      chapterCount: 10,
      elapsedSeconds: 29,
    )!;

    expect(tooFast.readChapterUrls, isEmpty);
    expect(tooFast.readingSeconds, 29);
    expect(ReadingXpStore(box: box).load().pagesRead, 0);

    final qualified = store.recordChapterReadingTime(
      novel.id,
      chapterUrl: 'https://example.com/timed-novel/chapter-1',
      chapterTitle: 'Chapter 1',
      chapterNumber: 1,
      chapterCount: 10,
      elapsedSeconds: 1,
    )!;

    expect(qualified.readChapterUrls, hasLength(1));
    expect(qualified.readingSeconds, 30);
    expect(ReadingXpStore(box: box).load().pagesRead, 1);

    final spammed = store.recordChapterReadingTime(
      novel.id,
      chapterUrl: 'https://example.com/timed-novel/chapter-2',
      chapterTitle: 'Chapter 2',
      chapterNumber: 2,
      chapterCount: 10,
      elapsedSeconds: 0,
    )!;

    expect(spammed.lastPageNumber, 2);
    expect(spammed.readChapterUrls, hasLength(1));
    expect(spammed.progressPercent, 10);
    expect(ReadingXpStore(box: box).load().pagesRead, 1);
  });

  test('calculates reading time remaining for the next novel tier', () {
    final novel = ReadingDocument.externalNovel(
      title: 'Progress Novel',
      sourceUrl: 'https://example.com/progress-novel',
      sourceName: 'Example Source',
    ).copyWith(
      readChapterUrls: ['chapter-1'],
      chapterReadingSeconds: {'chapter-2': 20},
    );

    expect(novel.novelReadingTier, NovelReadingTier.green);
    expect(novel.chaptersToNextNovelTier, 9);
    expect(
      novel.readingSecondsToNextNovelTier(secondsPerChapter: 30),
      250,
    );
  });
}
