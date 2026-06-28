import 'package:flutter/material.dart';

import '../../library/data/library_store.dart';
import '../../library/data/web_content_client.dart';
import '../../library/models/reading_document.dart';
import 'external_novel_reader_page.dart';

enum ChapterSortOrder {
  ascending,
  descending;

  String get label {
    return switch (this) {
      ChapterSortOrder.ascending => 'Ascending',
      ChapterSortOrder.descending => 'Descending',
    };
  }
}

class WebNovelChaptersPage extends StatefulWidget {
  const WebNovelChaptersPage({
    required this.document,
    super.key,
  });

  final ReadingDocument document;

  @override
  State<WebNovelChaptersPage> createState() => _WebNovelChaptersPageState();
}

class _WebNovelChaptersPageState extends State<WebNovelChaptersPage> {
  final store = LibraryStore();
  final contentClient = const WebContentClient();
  late ReadingDocument document;
  late Future<List<WebChapterEntry>> chaptersFuture;
  ChapterSortOrder order = ChapterSortOrder.ascending;

  @override
  void initState() {
    super.initState();
    document = widget.document;
    chaptersFuture = _loadChapters();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(document.title)),
      body: FutureBuilder<List<WebChapterEntry>>(
        future: chaptersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ChapterErrorCard(
              title: document.title,
              message: snapshot.error.toString(),
              onRetry: _refresh,
            );
          }

          final chapters = snapshot.data ?? const <WebChapterEntry>[];
          final displayedChapters = order == ChapterSortOrder.ascending
              ? chapters
              : chapters.reversed.toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        document.title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      if (document.sourceName != null) ...[
                        const SizedBox(height: 4),
                        Text(document.sourceName!),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.sort),
                                labelText: 'Chapter order',
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<ChapterSortOrder>(
                                  value: order,
                                  isExpanded: true,
                                  items: [
                                    for (final value in ChapterSortOrder.values)
                                      DropdownMenuItem(
                                        value: value,
                                        child: Text(value.label),
                                      ),
                                  ],
                                  onChanged: (value) {
                                    if (value == null) {
                                      return;
                                    }
                                    setState(() => order = value);
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: chapters.isEmpty
                                ? null
                                : () => _continueReading(chapters),
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Continue'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${chapters.length} chapters',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              for (final chapter in displayedChapters)
                _ChapterTile(
                  chapter: chapter,
                  chapterNumber: chapters.indexOf(chapter) + 1,
                  totalChapters: chapters.length,
                  read: document.readChapterUrls.contains(chapter.url),
                  lastRead: document.lastReadChapterUrl == chapter.url,
                  onTap: () => _openChapter(chapters, chapter),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<List<WebChapterEntry>> _loadChapters() {
    final sourceUrl = document.sourceUrl;
    if (sourceUrl == null || sourceUrl.trim().isEmpty) {
      throw const WebContentException('This novel has no source URL.');
    }
    return contentClient.fetchChapters(sourceUrl);
  }

  void _refresh() {
    setState(() {
      chaptersFuture = _loadChapters();
    });
  }

  Future<void> _continueReading(List<WebChapterEntry> chapters) async {
    final lastReadUrl = document.lastReadChapterUrl;
    final chapter = chapters.firstWhere(
      (chapter) => chapter.url == lastReadUrl,
      orElse: () => chapters.first,
    );
    await _openChapter(chapters, chapter);
  }

  Future<void> _openChapter(
    List<WebChapterEntry> chapters,
    WebChapterEntry chapter,
  ) async {
    final index = chapters.indexOf(chapter);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExternalNovelReaderPage(
          document: document,
          chapters: chapters,
          initialChapterIndex: index,
        ),
      ),
    );

    final refreshed = _documentFromStore();
    if (mounted && refreshed != null) {
      setState(() => document = refreshed);
    }
  }

  ReadingDocument? _documentFromStore() {
    for (final stored in store.documents()) {
      if (stored.id == document.id) {
        return stored;
      }
    }
    return null;
  }
}

class _ChapterTile extends StatelessWidget {
  const _ChapterTile({
    required this.chapter,
    required this.chapterNumber,
    required this.totalChapters,
    required this.read,
    required this.lastRead,
    required this.onTap,
  });

  final WebChapterEntry chapter;
  final int chapterNumber;
  final int totalChapters;
  final bool read;
  final bool lastRead;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: read ? colorScheme.surfaceContainerHighest : null,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor:
              read ? colorScheme.outlineVariant : colorScheme.primaryContainer,
          foregroundColor: read
              ? colorScheme.onSurfaceVariant
              : colorScheme.onPrimaryContainer,
          child: Text('$chapterNumber'),
        ),
        title: Text(
          chapter.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: read ? colorScheme.onSurfaceVariant : null,
          ),
        ),
        subtitle: Text('Chapter $chapterNumber of $totalChapters'),
        trailing: lastRead
            ? const Chip(label: Text('Last read'))
            : read
                ? const Icon(Icons.check_circle_outline)
                : const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _ChapterErrorCard extends StatelessWidget {
  const _ChapterErrorCard({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
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
