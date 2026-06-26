import 'package:flutter_reading_portfolio_app/features/extensions/data/extension_catalog_client.dart';
import 'package:flutter_reading_portfolio_app/features/extensions/models/extension_manifest.dart';
import 'package:flutter_reading_portfolio_app/features/extensions/models/extension_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('parses LNReader-style plugin lists', () async {
    final client = ExtensionCatalogClient(
      client: MockClient((request) async {
        return http.Response(
          '[{"id":"demo","name":"Demo Source","site":"https://example.com","lang":"English","version":"1.0.0","url":"https://example.com/demo.js","iconUrl":""}]',
          200,
        );
      }),
    );

    final extensions = await client.fetchRepository(
      ExtensionRepository.create('https://example.com/plugins.json'),
    );

    expect(extensions.single.id, 'demo');
    expect(extensions.single.name, 'Demo Source');
    expect(extensions.single.language, 'English');
  });

  test('downloads extension source', () async {
    final client = ExtensionCatalogClient(
      client: MockClient((request) async {
        return http.Response('export default {};', 200);
      }),
    );

    final source = await client.downloadSource(
      const ExtensionManifest(
        id: 'demo',
        name: 'Demo',
        site: 'https://example.com',
        language: 'English',
        version: '1.0.0',
        url: 'https://example.com/demo.js',
        iconUrl: '',
        repositoryUrl: 'https://example.com/plugins.json',
      ),
    );

    expect(source, contains('export'));
  });
}
