import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class WebContentClient {
  const WebContentClient({
    http.Client? client,
    Uri? webProxyBaseUri,
  })  : _client = client,
        _webProxyBaseUri = webProxyBaseUri;

  final http.Client? _client;
  final Uri? _webProxyBaseUri;

  Future<List<WebSourceEntry>> fetchEntries({
    required String url,
    required String sourceName,
  }) async {
    final body = await _get(url);
    final document = html_parser.parse(body);
    final baseUri = _parseHttpUri(url);
    final entriesByUrl = <String, WebSourceEntry>{};

    _removeNoisyNodes(document);

    for (final link in document.querySelectorAll('a[href]')) {
      final href = link.attributes['href'] ?? '';
      final resolvedUrl = _resolveUrl(baseUri, href);
      final title = _cleanText(link.text);
      if (resolvedUrl == null || !_looksLikeEntryTitle(title)) {
        continue;
      }

      final key = _withoutFragment(resolvedUrl);
      entriesByUrl.putIfAbsent(
        key,
        () => WebSourceEntry(
          title: title,
          url: key,
          sourceName: sourceName,
          description: _cleanText(link.attributes['title'] ?? ''),
          coverUrl: _coverUrlFor(link, baseUri),
        ),
      );

      if (entriesByUrl.length >= 100) {
        break;
      }
    }

    final entries = entriesByUrl.values.toList()
      ..sort((a, b) => a.title.compareTo(b.title));
    return entries;
  }

  Future<ReadableWebContent> fetchReadableContent(String url) async {
    final body = await _get(url);
    final document = html_parser.parse(body);
    _removeNoisyNodes(document);

    final title = _firstCleanText(
      [
        document.querySelector('article h1'),
        document.querySelector('main h1'),
        document.querySelector('h1'),
        document.querySelector('title'),
      ],
    );
    final root = document.querySelector('article') ??
        document.querySelector('main') ??
        document.querySelector('[role="main"]') ??
        document.body;
    final text = _cleanText(root?.text ?? document.documentElement?.text ?? '');

    return ReadableWebContent(
      title: title.isEmpty ? url : title,
      url: url,
      text: text,
    );
  }

  Future<String> _get(String url) async {
    final uri = _parseHttpUri(url);
    final client = _client ?? http.Client();
    try {
      final response = await _getWithProxyFallback(client, uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw WebContentException('Request returned ${response.statusCode}');
      }
      return response.body;
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  Future<http.Response> _getWithProxyFallback(
    http.Client client,
    Uri uri,
  ) async {
    try {
      return await client.get(uri);
    } catch (error) {
      if (!kIsWeb) {
        rethrow;
      }

      try {
        return await client.get(_proxyUriFor(uri));
      } catch (_) {
        throw WebContentException(
          'Could not fetch ${uri.toString()}. Chrome blocked the site request, '
          'and the local reading proxy is not reachable. Start it with '
          '`dart run tool/dev_proxy.dart` and try again.',
        );
      }
    }
  }

  Uri _proxyUriFor(Uri targetUri) {
    final proxyBaseUri =
        _webProxyBaseUri ?? Uri.parse('http://127.0.0.1:8787/fetch');
    return proxyBaseUri.replace(
      queryParameters: {
        ...proxyBaseUri.queryParameters,
        'url': targetUri.toString(),
      },
    );
  }

  Uri _parseHttpUri(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const WebContentException('Enter a valid http or https URL');
    }
    return uri;
  }

  String? _resolveUrl(Uri baseUri, String href) {
    final trimmed = href.trim();
    if (trimmed.isEmpty ||
        trimmed.startsWith('#') ||
        trimmed.startsWith('javascript:') ||
        trimmed.startsWith('mailto:') ||
        trimmed.startsWith('tel:')) {
      return null;
    }

    final uri = Uri.tryParse(trimmed);
    final resolved = uri == null ? null : baseUri.resolveUri(uri);
    if (resolved == null ||
        resolved.host.isEmpty ||
        (resolved.scheme != 'http' && resolved.scheme != 'https')) {
      return null;
    }
    return resolved.toString();
  }

  String? _coverUrlFor(dom.Element link, Uri baseUri) {
    final image = link.querySelector('img');
    final source = image?.attributes['src'] ?? image?.attributes['data-src'];
    if (source == null || source.trim().isEmpty) {
      return null;
    }
    return _resolveUrl(baseUri, source);
  }

  void _removeNoisyNodes(dom.Document document) {
    for (final selector in const [
      'script',
      'style',
      'noscript',
      'svg',
      'iframe',
      'form',
      'button',
      'header',
      'footer',
      'nav',
      'aside',
    ]) {
      for (final node in document.querySelectorAll(selector)) {
        node.remove();
      }
    }
  }

  String _firstCleanText(List<dom.Element?> elements) {
    for (final element in elements) {
      final text = _cleanText(element?.text ?? '');
      if (text.isNotEmpty) {
        return text;
      }
    }
    return '';
  }

  bool _looksLikeEntryTitle(String title) {
    if (title.length < 3 || title.length > 140) {
      return false;
    }

    final normalized = title.toLowerCase();
    const blocked = {
      'home',
      'login',
      'register',
      'privacy policy',
      'terms',
      'contact',
      'facebook',
      'twitter',
      'instagram',
      'discord',
      'rss',
    };
    return !blocked.contains(normalized);
  }

  String _withoutFragment(String url) {
    final uri = Uri.parse(url);
    return uri.replace(fragment: '').toString();
  }

  String _cleanText(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

class WebSourceEntry {
  const WebSourceEntry({
    required this.title,
    required this.url,
    required this.sourceName,
    this.description,
    this.coverUrl,
  });

  final String title;
  final String url;
  final String sourceName;
  final String? description;
  final String? coverUrl;
}

class ReadableWebContent {
  const ReadableWebContent({
    required this.title,
    required this.url,
    required this.text,
  });

  final String title;
  final String url;
  final String text;
}

class WebContentException implements Exception {
  const WebContentException(this.message);

  final String message;

  @override
  String toString() => message;
}
