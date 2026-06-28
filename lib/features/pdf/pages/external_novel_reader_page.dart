import 'dart:async';

import 'package:flutter/material.dart';

import '../../habits/data/reading_xp_store.dart';
import '../../library/data/library_store.dart';
import '../../library/data/web_content_client.dart';
import '../../library/models/reading_document.dart';

class ExternalNovelReaderPage extends StatefulWidget {
  const ExternalNovelReaderPage({
    required this.document,
    this.chapters = const [],
    this.initialChapterIndex = 0,
    super.key,
  });

  final ReadingDocument document;
  final List<WebChapterEntry> chapters;
  final int initialChapterIndex;

  @override
  State<ExternalNovelReaderPage> createState() =>
      _ExternalNovelReaderPageState();
}

class _ExternalNovelReaderPageState extends State<ExternalNovelReaderPage>
    with WidgetsBindingObserver {
  final store = LibraryStore();
  final xpStore = ReadingXpStore();
  final contentClient = const WebContentClient();
  late ReadingDocument document;
  late ReadingXpProgress xpProgress;
  late Future<ReadableWebContent> contentFuture;
  late int currentChapterIndex;
  Timer? readingTimer;
  int pendingReadingSeconds = 0;
  bool contentReady = false;
  int contentLoadGeneration = 0;

  bool get hasChapters => widget.chapters.isNotEmpty;

  WebChapterEntry? get currentChapter {
    if (!hasChapters ||
        currentChapterIndex < 0 ||
        currentChapterIndex >= widget.chapters.length) {
      return null;
    }
    return widget.chapters[currentChapterIndex];
  }

  bool get canGoPrevious => hasChapters && currentChapterIndex > 0;

  bool get canGoNext =>
      hasChapters && currentChapterIndex < widget.chapters.length - 1;

  bool get currentChapterQualified {
    final chapter = currentChapter;
    return chapter != null && document.readChapterUrls.contains(chapter.url);
  }

  int get currentChapterReadingSeconds {
    final chapter = currentChapter;
    if (chapter == null) {
      return 0;
    }
    return (document.chapterReadingSeconds[chapter.url] ?? 0) +
        pendingReadingSeconds;
  }

  int get secondsUntilChapterCounts =>
      (LibraryStore.minimumChapterReadSeconds - currentChapterReadingSeconds)
          .clamp(0, LibraryStore.minimumChapterReadSeconds)
          .toInt();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    currentChapterIndex = widget.initialChapterIndex.clamp(
      0,
      widget.chapters.isEmpty ? 0 : widget.chapters.length - 1,
    );
    document = widget.document;
    xpProgress = xpStore.load();
    contentFuture = _loadContentAndStartTimer();
    _recordCurrentChapterPosition();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopReadingTimer();
    _persistCurrentChapterTime(notify: false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startReadingTimer();
      return;
    }
    _stopReadingTimer();
    _persistCurrentChapterTime();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(document.title),
        actions: [
          _ReadingXpBadge(progress: xpProgress),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
          if (hasChapters) ...[
            IconButton(
              tooltip: 'Previous chapter',
              onPressed: canGoPrevious ? _previousChapter : null,
              icon: const Icon(Icons.skip_previous),
            ),
            IconButton(
              tooltip: 'Next chapter',
              onPressed: canGoNext ? _nextChapter : null,
              icon: const Icon(Icons.skip_next),
            ),
          ] else
            IconButton(
              tooltip: document.progress >= 1 ? 'Mark unread' : 'Mark read',
              onPressed: _toggleRead,
              icon: Icon(
                document.progress >= 1
                    ? Icons.bookmark_remove_outlined
                    : Icons.bookmark_added_outlined,
              ),
            ),
        ],
      ),
      body: FutureBuilder<ReadableWebContent>(
        future: contentFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ReaderError(
              title: document.title,
              url: document.sourceUrl,
              message: snapshot.error.toString(),
              onRetry: _refresh,
            );
          }

          final content = snapshot.data;
          if (content == null || content.text.isEmpty) {
            return _ReaderError(
              title: document.title,
              url: document.sourceUrl,
              message: 'No readable text found.',
              onRetry: _refresh,
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentChapter?.title ?? content.title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      if (xpProgress.readingTitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          xpProgress.readingTitle!,
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.tertiary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                      if (document.sourceName != null) ...[
                        const SizedBox(height: 4),
                        Text(document.sourceName!),
                      ],
                      if (hasChapters) ...[
                        const SizedBox(height: 4),
                        Text(
                          currentChapterQualified
                              ? 'Counted as read'
                              : 'Counts as read in $secondsUntilChapterCounts seconds',
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: currentChapterQualified
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                  ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          minHeight: 8,
                          value: document.progress,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (hasChapters) ...[
                        _ChapterControls(
                          currentChapterNumber: currentChapterIndex + 1,
                          totalChapters: widget.chapters.length,
                          canGoPrevious: canGoPrevious,
                          canGoNext: canGoNext,
                          onPrevious: _previousChapter,
                          onNext: _nextChapter,
                        ),
                        const SizedBox(height: 16),
                      ],
                      SelectableText(
                        content.text,
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(height: 1.6),
                      ),
                      if (hasChapters) ...[
                        const SizedBox(height: 24),
                        _ChapterControls(
                          currentChapterNumber: currentChapterIndex + 1,
                          totalChapters: widget.chapters.length,
                          canGoPrevious: canGoPrevious,
                          canGoNext: canGoNext,
                          onPrevious: _previousChapter,
                          onNext: _nextChapter,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<ReadableWebContent> _loadContent({bool forceRefresh = false}) async {
    final chapter = currentChapter;
    if (chapter != null) {
      return contentClient.fetchReadableContent(chapter.url);
    }

    final cachedText = document.sourceText;
    if (!forceRefresh && cachedText != null && cachedText.trim().length > 200) {
      return ReadableWebContent(
        title: document.title,
        url: document.sourceUrl ?? '',
        text: cachedText,
      );
    }

    final url = document.sourceUrl;
    if (url == null || url.trim().isEmpty) {
      throw const WebContentException('This library item has no source URL.');
    }

    final content = await contentClient.fetchReadableContent(url);
    final updatedDocument = store.updateDocumentSourceText(
      document.id,
      sourceText: content.text,
    );
    if (updatedDocument != null) {
      document = updatedDocument;
    }
    return content;
  }

  Future<ReadableWebContent> _loadContentAndStartTimer({
    bool forceRefresh = false,
  }) async {
    final generation = ++contentLoadGeneration;
    contentReady = false;
    _stopReadingTimer();
    final content = await _loadContent(forceRefresh: forceRefresh);
    if (!mounted || generation != contentLoadGeneration) {
      return content;
    }
    contentReady = true;
    _startReadingTimer();
    return content;
  }

  void _refresh() {
    _persistCurrentChapterTime();
    setState(() {
      contentFuture = _loadContentAndStartTimer(forceRefresh: true);
    });
  }

  void _toggleRead() {
    final previousTotalXp = xpProgress.totalXp;
    final updatedDocument = store.updateDocumentProgress(
      document.id,
      pageNumber: document.progress >= 1 ? 0 : 1,
      pageCount: 1,
    );
    if (updatedDocument == null) {
      return;
    }

    setState(() {
      document = updatedDocument;
      xpProgress = xpStore.load();
    });
    _showXpAward(xpProgress.totalXp - previousTotalXp);
  }

  void _previousChapter() {
    if (!canGoPrevious) {
      return;
    }
    _openChapterIndex(currentChapterIndex - 1);
  }

  void _nextChapter() {
    if (!canGoNext) {
      return;
    }
    _openChapterIndex(currentChapterIndex + 1);
  }

  void _openChapterIndex(int index) {
    _persistCurrentChapterTime();
    _stopReadingTimer();
    final chapter = widget.chapters[index];
    currentChapterIndex = index;
    pendingReadingSeconds = 0;
    final updatedDocument = store.recordChapterReadingTime(
      document.id,
      chapterUrl: chapter.url,
      chapterTitle: chapter.title,
      chapterNumber: index + 1,
      chapterCount: widget.chapters.length,
      elapsedSeconds: 0,
    );

    setState(() {
      document = updatedDocument ?? document;
      xpProgress = xpStore.load();
      contentFuture = _loadContentAndStartTimer(forceRefresh: true);
    });
  }

  void _startReadingTimer() {
    if (!hasChapters || !contentReady || readingTimer != null) {
      return;
    }
    readingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      pendingReadingSeconds++;
      final shouldPersist = pendingReadingSeconds >= 5;
      if (shouldPersist) {
        _persistCurrentChapterTime();
      }
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _stopReadingTimer() {
    readingTimer?.cancel();
    readingTimer = null;
  }

  void _recordCurrentChapterPosition() {
    final chapter = currentChapter;
    if (chapter == null) {
      return;
    }
    document = store.recordChapterReadingTime(
          document.id,
          chapterUrl: chapter.url,
          chapterTitle: chapter.title,
          chapterNumber: currentChapterIndex + 1,
          chapterCount: widget.chapters.length,
          elapsedSeconds: 0,
        ) ??
        document;
  }

  void _persistCurrentChapterTime({bool notify = true}) {
    final chapter = currentChapter;
    if (chapter == null || pendingReadingSeconds <= 0) {
      return;
    }

    final elapsedSeconds = pendingReadingSeconds;
    pendingReadingSeconds = 0;
    final previousTotalXp = xpProgress.totalXp;
    final updatedDocument = store.recordChapterReadingTime(
      document.id,
      chapterUrl: chapter.url,
      chapterTitle: chapter.title,
      chapterNumber: currentChapterIndex + 1,
      chapterCount: widget.chapters.length,
      elapsedSeconds: elapsedSeconds,
    );
    document = updatedDocument ?? document;
    xpProgress = xpStore.load();

    if (notify) {
      _showXpAward(xpProgress.totalXp - previousTotalXp);
    }
  }

  void _showXpAward(int xpEarned) {
    if (!mounted || xpEarned <= 0) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Chapter read: +$xpEarned XP')),
      );
  }
}

class _ReadingXpBadge extends StatelessWidget {
  const _ReadingXpBadge({required this.progress});

  final ReadingXpProgress progress;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Reading level ${progress.currentLevel}',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Center(
          child: Text(
            '${progress.totalXp} XP',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
      ),
    );
  }
}

class _ChapterControls extends StatelessWidget {
  const _ChapterControls({
    required this.currentChapterNumber,
    required this.totalChapters,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
  });

  final int currentChapterNumber;
  final int totalChapters;
  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.filledTonal(
          tooltip: 'Previous chapter',
          onPressed: canGoPrevious ? onPrevious : null,
          icon: const Icon(Icons.chevron_left),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Chapter $currentChapterNumber of $totalChapters',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: canGoNext ? onNext : null,
          icon: const Icon(Icons.chevron_right),
          label: const Text('Next'),
        ),
      ],
    );
  }
}

class _ReaderError extends StatelessWidget {
  const _ReaderError({
    required this.title,
    required this.url,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String? url;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (url != null) ...[
                  const SizedBox(height: 8),
                  SelectableText(url!),
                ],
                const SizedBox(height: 12),
                Text(message),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
