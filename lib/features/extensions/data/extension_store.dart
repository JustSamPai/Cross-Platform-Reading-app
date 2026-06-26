import 'package:hive/hive.dart';

import '../../../core/storage/reading_storage.dart';
import '../models/extension_manifest.dart';
import '../models/extension_repository.dart';

class ExtensionStore {
  ExtensionStore({Box<dynamic>? box}) : _box = box ?? ReadingStorage.box;

  static const _repositoriesKey = 'extensions.repositories';
  static const _downloadedKey = 'extensions.downloaded';

  final Box<dynamic> _box;

  List<ExtensionRepository> repositories() {
    final raw = _box.get(_repositoriesKey);
    if (raw is! List) {
      return const [];
    }

    return raw
        .whereType<Map<dynamic, dynamic>>()
        .map(ExtensionRepository.fromMap)
        .where((repository) => repository.url.isNotEmpty)
        .toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
  }

  List<ExtensionRepository> addRepository(String url) {
    final normalizedUrl = url.trim();
    if (!_isValidHttpUrl(normalizedUrl)) {
      return repositories();
    }

    final savedRepositories = repositories().toList();
    final alreadyExists = savedRepositories.any(
      (repository) => repository.url == normalizedUrl,
    );

    if (!alreadyExists) {
      savedRepositories.insert(0, ExtensionRepository.create(normalizedUrl));
      _saveRepositories(savedRepositories);
    }

    return repositories();
  }

  List<ExtensionRepository> deleteRepository(String url) {
    final savedRepositories = repositories().toList()
      ..removeWhere((repository) => repository.url == url);
    _saveRepositories(savedRepositories);
    return repositories();
  }

  List<ExtensionManifest> downloadedExtensions() {
    final raw = _box.get(_downloadedKey);
    if (raw is! List) {
      return const [];
    }

    return raw
        .whereType<Map<dynamic, dynamic>>()
        .map(ExtensionManifest.fromMap)
        .where((extension) => extension.id.isNotEmpty)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  bool isDownloaded(ExtensionManifest extension) {
    return downloadedExtensions().any((downloaded) {
      return downloaded.key == extension.key;
    });
  }

  List<ExtensionManifest> saveDownloadedExtension(
    ExtensionManifest extension, {
    required String sourceCode,
  }) {
    final downloaded = downloadedExtensions().toList()
      ..removeWhere((stored) => stored.key == extension.key);

    downloaded.add(
      extension.copyWith(
        sourceCode: sourceCode,
        downloadedAt: DateTime.now(),
      ),
    );
    _saveDownloaded(downloaded);
    return downloadedExtensions();
  }

  List<ExtensionManifest> deleteDownloadedExtension(
      ExtensionManifest extension) {
    final downloaded = downloadedExtensions().toList()
      ..removeWhere((stored) => stored.key == extension.key);
    _saveDownloaded(downloaded);
    return downloadedExtensions();
  }

  void _saveRepositories(List<ExtensionRepository> repositories) {
    _box.put(
      _repositoriesKey,
      repositories.map((repository) => repository.toMap()).toList(),
    );
  }

  void _saveDownloaded(List<ExtensionManifest> extensions) {
    _box.put(
      _downloadedKey,
      extensions.map((extension) => extension.toMap()).toList(),
    );
  }

  bool _isValidHttpUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null &&
        uri.host.isNotEmpty &&
        (uri.scheme == 'https' || uri.scheme == 'http');
  }
}
