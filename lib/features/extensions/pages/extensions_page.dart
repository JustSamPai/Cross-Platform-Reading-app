import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/storage/reading_storage.dart';
import '../../../core/widgets/page_frame.dart';
import '../../settings/pages/settings_page.dart';
import '../data/extension_catalog_client.dart';
import '../data/extension_store.dart';
import '../models/extension_manifest.dart';
import '../models/extension_repository.dart';
import 'extension_source_page.dart';

class ExtensionsPage extends StatefulWidget {
  const ExtensionsPage({super.key});

  @override
  State<ExtensionsPage> createState() => _ExtensionsPageState();
}

class _ExtensionsPageState extends State<ExtensionsPage> {
  final catalogClient = const ExtensionCatalogClient();
  final searchController = TextEditingController();
  final downloadingKeys = <String>{};
  Future<_CatalogLoadResult>? catalogFuture;
  String catalogSignature = '';
  String query = '';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<dynamic>>(
      valueListenable: ReadingStorage.box.listenable(),
      builder: (context, box, _) {
        final store = ExtensionStore(box: box);
        final repositories = store.repositories();
        final downloaded = store.downloadedExtensions();
        final downloadedByKey = {
          for (final extension in downloaded) extension.key: extension,
        };
        final signature = repositories.map((repo) => repo.url).join('|');
        if (signature != catalogSignature) {
          catalogSignature = signature;
          catalogFuture = _loadCatalog(repositories);
        }

        return PageFrame(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Extensions',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: repositories.isEmpty
                        ? null
                        : () {
                            setState(() {
                              catalogFuture = _loadCatalog(repositories);
                            });
                          },
                    icon: const Icon(Icons.refresh),
                  ),
                  IconButton(
                    tooltip: 'Settings',
                    onPressed: _openSettings,
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (repositories.isEmpty)
                _EmptyExtensionsState(
                  onOpenSettings: _openSettings,
                )
              else ...[
                TextField(
                  controller: searchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Search extensions',
                  ),
                  onChanged: (value) {
                    setState(() => query = value.trim().toLowerCase());
                  },
                ),
                const SizedBox(height: 16),
                if (downloaded.isNotEmpty) ...[
                  Text(
                    'Downloaded',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  for (final extension in downloaded)
                    _ExtensionTile(
                      extension: extension,
                      downloaded: true,
                      busy: downloadingKeys.contains(extension.key),
                      onOpen: () => _openSource(extension),
                      onDownload: () => _downloadExtension(store, extension),
                      onRemove: () =>
                          store.deleteDownloadedExtension(extension),
                    ),
                  const SizedBox(height: 16),
                ],
                Text(
                  'Available',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                FutureBuilder<_CatalogLoadResult>(
                  future: catalogFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    final result = snapshot.data;
                    if (snapshot.hasError || result == null) {
                      return _CatalogErrorCard(
                        message: snapshot.error?.toString() ??
                            'Could not load repositories',
                      );
                    }

                    final downloadedKeys =
                        downloaded.map((extension) => extension.key).toSet();
                    final extensions = result.extensions.where((extension) {
                      if (query.isEmpty) {
                        return true;
                      }
                      return extension.name.toLowerCase().contains(query) ||
                          extension.language.toLowerCase().contains(query) ||
                          extension.site.toLowerCase().contains(query);
                    }).toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (result.errors.isNotEmpty)
                          _CatalogErrorCard(
                            message: result.errors.join('\n'),
                          ),
                        if (extensions.isEmpty)
                          const Card(
                            margin: EdgeInsets.zero,
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('No matching extensions.'),
                            ),
                          )
                        else
                          for (final extension in extensions)
                            _ExtensionTile(
                              extension:
                                  downloadedByKey[extension.key] ?? extension,
                              downloaded:
                                  downloadedKeys.contains(extension.key),
                              busy: downloadingKeys.contains(extension.key),
                              onOpen: downloadedByKey[extension.key] == null
                                  ? null
                                  : () {
                                      _openSource(
                                        downloadedByKey[extension.key]!,
                                      );
                                    },
                              onDownload: () {
                                _downloadExtension(store, extension);
                              },
                              onRemove: () {
                                store.deleteDownloadedExtension(extension);
                              },
                            ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<_CatalogLoadResult> _loadCatalog(
    List<ExtensionRepository> repositories,
  ) async {
    final extensionsByKey = <String, ExtensionManifest>{};
    final errors = <String>[];

    for (final repository in repositories) {
      try {
        final extensions = await catalogClient.fetchRepository(repository);
        for (final extension in extensions) {
          extensionsByKey[extension.key] = extension;
        }
      } catch (error) {
        errors.add('${repository.url}: $error');
      }
    }

    final extensions = extensionsByKey.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return _CatalogLoadResult(extensions: extensions, errors: errors);
  }

  Future<void> _downloadExtension(
    ExtensionStore store,
    ExtensionManifest extension,
  ) async {
    setState(() => downloadingKeys.add(extension.key));
    try {
      final sourceCode = await catalogClient.downloadSource(extension);
      store.saveDownloadedExtension(extension, sourceCode: sourceCode);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${extension.name} downloaded')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => downloadingKeys.remove(extension.key));
      }
    }
  }

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsPage()),
    );
  }

  Future<void> _openSource(ExtensionManifest extension) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExtensionSourcePage(extension: extension),
      ),
    );
  }
}

class _CatalogLoadResult {
  const _CatalogLoadResult({
    required this.extensions,
    required this.errors,
  });

  final List<ExtensionManifest> extensions;
  final List<String> errors;
}

class _EmptyExtensionsState extends StatelessWidget {
  const _EmptyExtensionsState({
    required this.onOpenSettings,
  });

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('No extension repositories saved.'),
            FilledButton.icon(
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Add repository'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogErrorCard extends StatelessWidget {
  const _CatalogErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          style: TextStyle(color: colorScheme.onErrorContainer),
        ),
      ),
    );
  }
}

class _ExtensionTile extends StatelessWidget {
  const _ExtensionTile({
    required this.extension,
    required this.downloaded,
    required this.busy,
    required this.onOpen,
    required this.onDownload,
    required this.onRemove,
  });

  final ExtensionManifest extension;
  final bool downloaded;
  final bool busy;
  final VoidCallback? onOpen;
  final VoidCallback onDownload;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ExtensionIcon(url: extension.iconUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    extension.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (extension.language.isNotEmpty) extension.language,
                      if (extension.version.isNotEmpty) 'v${extension.version}',
                    ].join(' - '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (extension.site.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      extension.site,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (busy)
              const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (downloaded)
              Wrap(
                spacing: 4,
                children: [
                  IconButton.filled(
                    tooltip: 'Open source',
                    onPressed: onOpen,
                    icon: const Icon(Icons.open_in_new),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Remove download',
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              )
            else
              IconButton.filled(
                tooltip: 'Download extension',
                onPressed: onDownload,
                icon: const Icon(Icons.download),
              ),
            const SizedBox(width: 4),
            Icon(
              downloaded ? Icons.check_circle : Icons.public,
              color: downloaded ? colorScheme.primary : colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExtensionIcon extends StatelessWidget {
  const _ExtensionIcon({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ColoredBox(
        color: colorScheme.surfaceContainerHighest,
        child: SizedBox.square(
          dimension: 44,
          child: url.isEmpty
              ? Icon(Icons.extension_outlined, color: colorScheme.primary)
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (context, _, __) {
                    return Icon(
                      Icons.extension_outlined,
                      color: colorScheme.primary,
                    );
                  },
                ),
        ),
      ),
    );
  }
}
