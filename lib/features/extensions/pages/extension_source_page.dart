import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../library/data/library_store.dart';
import '../../library/data/web_content_client.dart';
import '../../library/models/reading_document.dart';
import '../../pdf/pages/web_novel_chapters_page.dart';
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
  late final List<_SourceCategory> categories;
  late _SourceCategory selectedCategory;
  Future<List<WebSourceEntry>>? entriesFuture;
  String query = '';

  @override
  void initState() {
    super.initState();
    categories = _SourceCategoryParser(widget.extension).parse();
    selectedCategory = categories.first;
    sourceUrlController.text = selectedCategory.url;
    if (selectedCategory.url.isNotEmpty) {
      entriesFuture = _loadEntries(selectedCategory.url);
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
                InputDecorator(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.category_outlined),
                    labelText: 'Category',
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<_SourceCategory>(
                      value: categories.contains(selectedCategory)
                          ? selectedCategory
                          : null,
                      isExpanded: true,
                      items: [
                        for (final category in categories)
                          DropdownMenuItem(
                            value: category,
                            child: Text(category.label),
                          ),
                      ],
                      onChanged: (category) {
                        if (category == null) {
                          return;
                        }
                        _selectCategory(category);
                      },
                    ),
                  ),
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
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${entries.length} novels in ${selectedCategory.label}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 12),
                _SourceEntryGrid(
                  entries: entries,
                  savedUrls: savedUrls,
                  onSave: _saveEntry,
                  onOpen: _openEntry,
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
      selectedCategory = _SourceCategory.custom(url);
      entriesFuture = _loadEntries(url);
    });
  }

  void _selectCategory(_SourceCategory category) {
    setState(() {
      selectedCategory = category;
      sourceUrlController.text = category.url;
      query = '';
      searchController.clear();
      entriesFuture = _loadEntries(category.url);
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
        builder: (context) => WebNovelChaptersPage(document: document),
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }
}

class _SourceCategory {
  const _SourceCategory({
    required this.label,
    required this.url,
  });

  factory _SourceCategory.custom(String url) {
    return _SourceCategory(label: 'Custom URL', url: url);
  }

  final String label;
  final String url;

  @override
  bool operator ==(Object other) {
    return other is _SourceCategory && other.label == label && other.url == url;
  }

  @override
  int get hashCode => Object.hash(label, url);
}

class _SourceCategoryParser {
  const _SourceCategoryParser(this.extension);

  final ExtensionManifest extension;

  List<_SourceCategory> parse() {
    final categoriesByUrl = <String, _SourceCategory>{};
    final sourceCode = extension.sourceCode ?? '';

    for (final option in _optionsFor(sourceCode, 'type')) {
      final url = _categoryUrl(option.value);
      categoriesByUrl[url] = _SourceCategory(
        label: _popularLabel(option.label),
        url: url,
      );
    }

    for (final option in _optionsFor(sourceCode, 'genres')) {
      final url = _categoryUrl(option.value);
      categoriesByUrl[url] = _SourceCategory(
        label: option.label,
        url: url,
      );
    }

    if (categoriesByUrl.isEmpty) {
      final url = extension.site.trim();
      return [_SourceCategory(label: 'Popular', url: url)];
    }

    final categories = categoriesByUrl.values.toList();
    categories.sort((a, b) {
      final aPopular = _isPopular(a);
      final bPopular = _isPopular(b);
      if (aPopular != bPopular) {
        return aPopular ? -1 : 1;
      }
      return a.label.compareTo(b.label);
    });
    return categories;
  }

  Iterable<_FilterOption> _optionsFor(String sourceCode, String filterName) {
    final match = RegExp(
      '$filterName:\\{[\\s\\S]*?options:\\[(.*?)\\]\\}',
    ).firstMatch(sourceCode);
    final optionsSource = match?.group(1);
    if (optionsSource == null || optionsSource.isEmpty) {
      return const [];
    }

    return RegExp(
      r'label:"([^"]+)",value:"([^"]*)"',
    ).allMatches(optionsSource).map((match) {
      return _FilterOption(
        label: _decodeOptionText(match.group(1) ?? ''),
        value: _decodeOptionText(match.group(2) ?? ''),
      );
    }).where((option) {
      return option.label.isNotEmpty && option.value.isNotEmpty;
    });
  }

  String _categoryUrl(String value) {
    final directUri = Uri.tryParse(value);
    if (directUri != null &&
        directUri.host.isNotEmpty &&
        (directUri.scheme == 'http' || directUri.scheme == 'https')) {
      return _withPage(directUri).toString();
    }

    final baseUri = Uri.tryParse(extension.site.trim());
    if (baseUri == null || baseUri.host.isEmpty) {
      return value;
    }

    final normalizedBase = baseUri.path.endsWith('/')
        ? baseUri
        : baseUri.replace(path: '${baseUri.path}/');
    return _withPage(normalizedBase.resolve(value)).toString();
  }

  Uri _withPage(Uri uri) {
    if (uri.queryParameters.containsKey('page')) {
      return uri;
    }

    return uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        'page': '1',
      },
    );
  }

  String _popularLabel(String label) {
    final normalized = label.trim().toLowerCase();
    if (normalized == 'most popular') {
      return 'Popular';
    }
    return label.trim();
  }

  bool _isPopular(_SourceCategory category) {
    final label = category.label.toLowerCase();
    final url = category.url.toLowerCase();
    return label == 'popular' || url.contains('most-popular');
  }

  String _decodeOptionText(String value) {
    return value
        .replaceAll(r'\"', '"')
        .replaceAll(r'\+', '+')
        .replaceAll(r'\/', '/')
        .trim();
  }
}

class _FilterOption {
  const _FilterOption({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}

class _SourceEntryGrid extends StatelessWidget {
  const _SourceEntryGrid({
    required this.entries,
    required this.savedUrls,
    required this.onSave,
    required this.onOpen,
  });

  final List<WebSourceEntry> entries;
  final Set<String> savedUrls;
  final ValueChanged<WebSourceEntry> onSave;
  final ValueChanged<WebSourceEntry> onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cardWidth = width >= 1040
            ? (width - 36) / 4
            : width >= 760
                ? (width - 24) / 3
                : width >= 520
                    ? (width - 12) / 2
                    : width;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final entry in entries)
              SizedBox(
                width: cardWidth,
                child: _SourceEntryCard(
                  entry: entry,
                  saved: savedUrls.contains(entry.url),
                  onSave: () => onSave(entry),
                  onOpen: () => onOpen(entry),
                ),
              ),
          ],
        );
      },
    );
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

class _SourceEntryCard extends StatelessWidget {
  const _SourceEntryCard({
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
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 3 / 4,
              child: _SourceCover(
                imageUrl: entry.coverUrl,
                title: entry.title,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 44,
                    child: Text(
                      entry.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 36,
                    child: Text(
                      entry.description?.isNotEmpty == true
                          ? entry.description!
                          : entry.url,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        saved
                            ? Icons.bookmark_added
                            : Icons.bookmark_border_outlined,
                        color:
                            saved ? colorScheme.primary : colorScheme.outline,
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: saved ? 'Saved' : 'Save',
                        onPressed: saved ? null : onSave,
                        icon: Icon(
                          saved
                              ? Icons.bookmark_added
                              : Icons.bookmark_add_outlined,
                        ),
                      ),
                      IconButton.filled(
                        tooltip: 'Read',
                        onPressed: onOpen,
                        icon: const Icon(Icons.chrome_reader_mode_outlined),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceCover extends StatelessWidget {
  const _SourceCover({
    required this.imageUrl,
    required this.title,
  });

  final String? imageUrl;
  final String title;

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, _, __) {
          return _BlankCover(title: title);
        },
      );
    }

    return _BlankCover(title: title);
  }
}

class _BlankCover extends StatelessWidget {
  const _BlankCover({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book_outlined,
              color: colorScheme.primary,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
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
