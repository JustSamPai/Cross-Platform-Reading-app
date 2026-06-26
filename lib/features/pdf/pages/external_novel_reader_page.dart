import 'package:flutter/material.dart';

import '../../library/data/library_store.dart';
import '../../library/data/web_content_client.dart';
import '../../library/models/reading_document.dart';

class ExternalNovelReaderPage extends StatefulWidget {
  const ExternalNovelReaderPage({
    required this.document,
    super.key,
  });

  final ReadingDocument document;

  @override
  State<ExternalNovelReaderPage> createState() =>
      _ExternalNovelReaderPageState();
}

class _ExternalNovelReaderPageState extends State<ExternalNovelReaderPage> {
  final store = LibraryStore();
  final contentClient = const WebContentClient();
  late ReadingDocument document;
  late Future<ReadableWebContent> contentFuture;

  @override
  void initState() {
    super.initState();
    document = widget.document;
    contentFuture = _loadContent();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(document.title),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
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
                        content.title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      if (document.sourceName != null) ...[
                        const SizedBox(height: 4),
                        Text(document.sourceName!),
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
                      SelectableText(
                        content.text,
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(height: 1.6),
                      ),
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

  void _refresh() {
    setState(() {
      contentFuture = _loadContent(forceRefresh: true);
    });
  }

  void _toggleRead() {
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
    });
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
