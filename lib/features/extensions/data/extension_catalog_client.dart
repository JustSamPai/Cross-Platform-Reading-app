import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/extension_manifest.dart';
import '../models/extension_repository.dart';

class ExtensionCatalogClient {
  const ExtensionCatalogClient({http.Client? client}) : _client = client;

  final http.Client? _client;

  Future<List<ExtensionManifest>> fetchRepository(
    ExtensionRepository repository,
  ) async {
    final client = _client ?? http.Client();
    try {
      final response = await client.get(Uri.parse(repository.url));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ExtensionCatalogException(
          'Repository returned ${response.statusCode}',
        );
      }

      final decoded = jsonDecode(response.body);
      final items = _extractItems(decoded);
      return items
          .whereType<Map<String, dynamic>>()
          .map((json) {
            return ExtensionManifest.fromJson(
              json: json,
              repositoryUrl: repository.url,
            );
          })
          .where((extension) => extension.id.isNotEmpty)
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
    } on FormatException catch (error) {
      throw ExtensionCatalogException('Repository JSON is invalid: $error');
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  Future<String> downloadSource(ExtensionManifest extension) async {
    if (extension.url.isEmpty) {
      throw ExtensionCatalogException(
          'Extension does not provide a source URL');
    }

    final client = _client ?? http.Client();
    try {
      final response = await client.get(Uri.parse(extension.url));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ExtensionCatalogException(
          'Extension returned ${response.statusCode}',
        );
      }
      return response.body;
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  List<Object?> _extractItems(Object? decoded) {
    if (decoded is List) {
      return decoded;
    }

    if (decoded is Map<String, dynamic>) {
      final candidates = [
        decoded['plugins'],
        decoded['extensions'],
        decoded['sources'],
        decoded['items'],
        decoded['data'],
      ];

      for (final candidate in candidates) {
        if (candidate is List) {
          return candidate;
        }
      }
    }

    throw ExtensionCatalogException('Repository JSON must contain a list');
  }
}

class ExtensionCatalogException implements Exception {
  const ExtensionCatalogException(this.message);

  final String message;

  @override
  String toString() => message;
}
