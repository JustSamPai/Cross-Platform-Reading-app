import 'dart:async';

import 'package:epub_view/epub_view.dart';
import 'package:flutter/material.dart';

import '../../library/data/library_store.dart';
import '../../library/models/reading_document.dart';

class EpubReaderPage extends StatefulWidget {
  const EpubReaderPage({
    required this.document,
    super.key,
  });

  final ReadingDocument document;

  @override
  State<EpubReaderPage> createState() => _EpubReaderPageState();
}

class _EpubReaderPageState extends State<EpubReaderPage> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final store = LibraryStore();
  late ReadingDocument document;
  late EpubController epubController;
  int currentChapter = 1;
  int chapterCount = 0;
  double chapterProgress = 0;
  Timer? progressDebounce;

  @override
  void initState() {
    super.initState();
    document = widget.document;
    currentChapter = document.lastPageNumber;
    chapterCount = document.pageCount;
    epubController = EpubController(
      document: EpubDocument.openData(document.bytes!),
      epubCfi: document.epubCfi,
    );
  }

  @override
  void dispose() {
    progressDebounce?.cancel();
    epubController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!document.canOpenInApp) {
      return Scaffold(
        appBar: AppBar(title: Text(document.title)),
        body: const Center(
          child: Text('Re-import this EPUB to open the reader.'),
        ),
      );
    }

    return Scaffold(
      key: scaffoldKey,
      appBar: AppBar(
        title: Text(document.title),
        actions: [
          IconButton(
            tooltip: 'Table of contents',
            onPressed: () => scaffoldKey.currentState?.openDrawer(),
            icon: const Icon(Icons.list_alt_outlined),
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: EpubViewTableOfContents(controller: epubController),
        ),
      ),
      body: Column(
        children: [
          _EpubProgressHeader(
            currentChapter: currentChapter,
            chapterCount: chapterCount,
            chapterProgress: chapterProgress,
          ),
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: EpubViewActualChapter(
                controller: epubController,
                builder: (chapterValue) {
                  final title = chapterValue?.chapter?.Title
                      ?.replaceAll('\n', ' ')
                      .trim();
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title == null || title.isEmpty
                          ? 'Chapter $currentChapter'
                          : title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  );
                },
              ),
            ),
          ),
          Expanded(
            child: EpubView(
              controller: epubController,
              onDocumentLoaded: _handleDocumentLoaded,
              onChapterChanged: _handleChapterChanged,
              onDocumentError: (error) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(error?.toString() ?? 'Could not open EPUB'),
                  ),
                );
              },
              builders: EpubViewBuilders<DefaultBuilderOptions>(
                options: DefaultBuilderOptions(
                  textStyle: Theme.of(context).textTheme.bodyLarge ??
                      const TextStyle(fontSize: 16),
                  paragraphPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                ),
                chapterDividerBuilder: (chapter) => Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                  child: Text(
                    chapter.Title?.replaceAll('\n', ' ').trim() ?? '',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleDocumentLoaded(EpubBook book) {
    final total = epubController.tableOfContents().length;
    final fallbackTotal = book.Chapters?.length ?? 0;
    final nextCount = total == 0 ? fallbackTotal : total;

    setState(() {
      chapterCount = nextCount;
      document = store.updateDocumentProgress(
            document.id,
            pageNumber: currentChapter,
            pageCount: nextCount,
            epubCfi: document.epubCfi,
          ) ??
          document.copyWith(pageCount: nextCount);
    });
  }

  void _handleChapterChanged(dynamic value) {
    if (value == null) {
      return;
    }

    final nextChapter = value.chapterNumber <= 0 ? 1 : value.chapterNumber;
    final nextProgress = value.progress.clamp(0, 100).toDouble();

    setState(() {
      currentChapter = nextChapter;
      chapterProgress = nextProgress;
    });

    progressDebounce?.cancel();
    progressDebounce = Timer(const Duration(milliseconds: 500), () {
      final cfi = epubController.generateEpubCfi();
      final updatedDocument = store.updateDocumentProgress(
        document.id,
        pageNumber: nextChapter,
        pageCount: chapterCount,
        epubCfi: cfi,
      );
      if (updatedDocument != null && mounted) {
        setState(() => document = updatedDocument);
      }
    });
  }
}

class _EpubProgressHeader extends StatelessWidget {
  const _EpubProgressHeader({
    required this.currentChapter,
    required this.chapterCount,
    required this.chapterProgress,
  });

  final int currentChapter;
  final int chapterCount;
  final double chapterProgress;

  @override
  Widget build(BuildContext context) {
    final progress = chapterCount <= 0 ? 0.0 : currentChapter / chapterCount;
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ProgressChip(
                  icon: Icons.menu_book_outlined,
                  label:
                      '$currentChapter / ${chapterCount == 0 ? '-' : chapterCount}',
                ),
                _ProgressChip(
                  icon: Icons.timeline_outlined,
                  label: '${(progress * 100).clamp(0, 100).round()}%',
                ),
                _ProgressChip(
                  icon: Icons.article_outlined,
                  label: '${chapterProgress.round()}% in chapter',
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: progress.clamp(0, 1).toDouble(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressChip extends StatelessWidget {
  const _ProgressChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colorScheme.primary),
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}
