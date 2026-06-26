import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../library/data/library_store.dart';
import '../../library/data/web_content_client.dart';
import '../../library/models/reading_document.dart';
import '../../pdf/pages/external_novel_reader_page.dart';
import '../models/extension_manifest.dart';

class ExtensionSourcePage extends StatefulWidget {
  const ExtensionSourcePage({
    required this.extension,
    super.key,
  });

  final ExtensionManifest extension;

  @override
  State<ExtensionSourcePage> createState() => _ExtensionSourcePageState();
}

class _ExtensionSourcePageState extends State<ExtensionSourcePage> {
  final contentClient = const WebContentClient();
  final libraryStore = LibraryStore();
  final sourceUrlController = TextEditingController();
  final searchController = TextEditingController();
  final manualTitleController = TextEditingController();
  final manualUrlController = TextEditingController();
  Future<List<WebSourceEntry>>? entriesFuture;
  String query = '';

  @override
  void initState() {
    super.initState();
    sourceUrlController.text = widget.extension.site;
    if (widget.extension.site.isNotEmpty) {
      entriesFuture = _loadEntries(widget.extension.site);
    }
  }

  @override
  void dispose() {
    sourceUrlController.dispose();
    searchController.dispose();
    manualTitleController.dispose();
    manualUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.extension.name),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.travel_explore), text: 'Entries'),
              Tab(icon: Icon(Icons.code), text: 'Source'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildEntriesTab(),
            _buildSourceTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildEntriesTab() {
    final savedUrls = libraryStore
        .documents()
        .where((document) => document.type == ReadingDocumentType.webNovel)
        .map((document) => document.sourceUrl)
        .whereType<String>()
        .toSet();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: sourceUrlController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.link),
                    labelText: 'Source URL',
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _loadCurrentSourceUrl(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          labelText: 'Filter entries',
                        ),
                        onChanged: (value) {
                          setState(() => query = value.trim().toLowerCase());
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton.filled(
                      tooltip: 'Load entries',
                      onPressed: _loadCurrentSourceUrl,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _ManualEntryCard(
          titleController: manualTitleController,
          urlController: manualUrlController,
          onSave: _saveManualEntry,
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<WebSourceEntry>>(
          future: entriesFuture,
          builder: (context, snapshot) {
            if (entriesFuture == null) {
              return const Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Enter a source URL to load entries.'),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (snapshot.hasError) {
              return _SourceErrorCard(message: snapshot.error.toString());
            }

            final entries =
                (snapshot.data ?? const <WebSourceEntry>[]).where((entry) {
              if (query.isEmpty) {
                return true;
              }
              return entry.title.toLowerCase().contains(query) ||
                  entry.url.toLowerCase().contains(query);
            }).toList();

            if (entries.isEmpty) {
              return const Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No entries found.'),
                ),
              );
            }

            return Column(
              children: [
                for (final entry in entries)
                  _SourceEntryTile(
                    entry: entry,
                    saved: savedUrls.contains(entry.url),
                    onSave: () => _saveEntry(entry),
                    onOpen: () => _openEntry(entry),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildSourceTab() {
    final sourceCode = widget.extension.sourceCode?.trim() ?? '';
    final displaySource = sourceCode
        .replaceAll(';', ';\n')
        .replaceAll('},{', '},\n{')
        .replaceAll('},function', '},\nfunction');

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
                  widget.extension.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (widget.extension.language.isNotEmpty)
                      Chip(label: Text(widget.extension.language)),
                    if (widget.extension.version.isNotEmpty)
                      Chip(label: Text('v${widget.extension.version}')),
                    if (widget.extension.site.isNotEmpty)
                      Chip(label: Text(widget.extension.site)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Source code',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy source code',
                      onPressed: sourceCode.isEmpty
                          ? null
                          : () => Clipboard.setData(
                                ClipboardData(text: sourceCode),
                              ),
                      icon: const Icon(Icons.copy),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SelectableText(
                  sourceCode.isEmpty
                      ? 'Source code is not downloaded.'
                      : displaySource,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        height: 1.35,
                      ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<List<WebSourceEntry>> _loadEntries(String url) {
    return contentClient.fetchEntries(
      url: url,
      sourceName: widget.extension.name,
    );
  }

  void _loadCurrentSourceUrl() {
    final url = sourceUrlController.text.trim();
    if (url.isEmpty) {
      return;
    }

    setState(() {
      entriesFuture = _loadEntries(url);
    });
  }

  void _saveManualEntry() {
    final url = manualUrlController.text.trim();
    if (url.isEmpty) {
      return;
    }
    if (!_isValidHttpUrl(url)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid http or https URL')),
      );
      return;
    }

    final entry = WebSourceEntry(
      title: manualTitleController.text.trim().isEmpty
          ? url
          : manualTitleController.text.trim(),
      url: url,
      sourceName: widget.extension.name,
    );
    _saveEntry(entry);
    manualTitleController.clear();
    manualUrlController.clear();
  }

  ReadingDocument _saveEntry(WebSourceEntry entry) {
    final before = libraryStore.documents();
    final alreadySaved = before.any((document) {
      return document.type == ReadingDocumentType.webNovel &&
          document.sourceUrl == entry.url;
    });

    final documents = libraryStore.addDocument(
      ReadingDocument.externalNovel(
        title: entry.title,
        sourceUrl: entry.url,
        sourceName: entry.sourceName,
        description: entry.description,
        coverUrl: entry.coverUrl,
      ),
    );
    final savedDocument = documents.firstWhere(
      (document) => document.sourceUrl == entry.url,
    );

    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(alreadySaved ? 'Already in library' : 'Saved to library'),
        ),
      );
    }

    return savedDocument;
  }

  bool _isValidHttpUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null &&
        uri.host.isNotEmpty &&
        (uri.scheme == 'https' || uri.scheme == 'http');
  }

  Future<void> _openEntry(WebSourceEntry entry) async {
    final document = _saveEntry(entry);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExternalNovelReaderPage(document: document),
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }
}

class _ManualEntryCard extends StatelessWidget {
  const _ManualEntryCard({
    required this.titleController,
    required this.urlController,
    required this.onSave,
  });

  final TextEditingController titleController;
  final TextEditingController urlController;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        leading: const Icon(Icons.add_link),
        title: const Text('Add entry'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          TextField(
            controller: titleController,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: urlController,
            decoration: const InputDecoration(labelText: 'Entry URL'),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onSave(),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: onSave,
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceEntryTile extends StatelessWidget {
  const _SourceEntryTile({
    required this.entry,
    required this.saved,
    required this.onSave,
    required this.onOpen,
  });

  final WebSourceEntry entry;
  final bool saved;
  final VoidCallback onSave;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: entry.coverUrl == null
            ? Icon(Icons.menu_book_outlined, color: colorScheme.primary)
            : ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  entry.coverUrl!,
                  width: 44,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (context, _, __) {
                    return Icon(
                      Icons.menu_book_outlined,
                      color: colorScheme.primary,
                    );
                  },
                ),
              ),
        title: Text(entry.title),
        subtitle: Text(
          entry.url,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              tooltip: saved ? 'Saved' : 'Save',
              onPressed: saved ? null : onSave,
              icon: Icon(
                saved ? Icons.bookmark_added : Icons.bookmark_add_outlined,
              ),
            ),
            IconButton.filled(
              tooltip: 'Read',
              onPressed: onOpen,
              icon: const Icon(Icons.chrome_reader_mode_outlined),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceErrorCard extends StatelessWidget {
  const _SourceErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      color: colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          message,
          style: TextStyle(color: colorScheme.onErrorContainer),
        ),
      ),
    );
  }
}
