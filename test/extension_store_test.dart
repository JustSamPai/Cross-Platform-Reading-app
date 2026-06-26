import 'dart:io';

import 'package:flutter_reading_portfolio_app/core/storage/reading_storage.dart';
import 'package:flutter_reading_portfolio_app/features/extensions/data/extension_store.dart';
import 'package:flutter_reading_portfolio_app/features/extensions/models/extension_manifest.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;
  late Box<dynamic> box;

  setUp(() async {
    tempDir =
        await Directory.systemTemp.createTemp('readflow_extensions_test_');
    Hive.init(tempDir.path);
    box = await Hive.openBox(ReadingStorage.boxName);
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('stores repositories and downloaded extensions', () {
    final store = ExtensionStore(box: box);
    const repositoryUrl = 'https://example.com/plugins.json';
    const extension = ExtensionManifest(
      id: 'demo',
      name: 'Demo',
      site: 'https://example.com',
      language: 'English',
      version: '1.0.0',
      url: 'https://example.com/demo.js',
      iconUrl: '',
      repositoryUrl: repositoryUrl,
    );

    store.addRepository(repositoryUrl);
    store.saveDownloadedExtension(extension, sourceCode: 'export default {};');

    expect(store.repositories().single.url, repositoryUrl);
    expect(store.isDownloaded(extension), isTrue);
    expect(store.downloadedExtensions().single.sourceCode, contains('export'));
  });
}
