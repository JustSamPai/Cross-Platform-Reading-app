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
    _extractStructuredEntries(
      document: document,
      baseUri: baseUri,
      sourceName: sourceName,
      entriesByUrl: entriesByUrl,
    );

    if (entriesByUrl.isEmpty) {
      for (final link in document.querySelectorAll('a[href]')) {
        final href = link.attributes['href'] ?? '';
        final resolvedUrl = _resolveUrl(baseUri, href);
        final title = _cleanText(link.attributes['title'] ?? link.text);
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
    }

    final entries = entriesByUrl.values.toList()
      ..sort((a, b) => a.title.compareTo(b.title));
    return entries;
  }

  void _extractStructuredEntries({
    required dom.Document document,
    required Uri baseUri,
    required String sourceName,
    required Map<String, WebSourceEntry> entriesByUrl,
  }) {
    final containers = document.querySelectorAll(
      '.archive .row, '
      '.col-content .row, '
      '.list-truyen .row, '
      '.novel-item, '
      '.book-item, '
      '.m-imgtxt',
    );

    for (final container in containers) {
      final link = container.querySelector('h3 a[href]') ??
          container.querySelector('.truyen-title a[href]') ??
          container.querySelector('a[href][title]');
      if (link == null) {
        continue;
      }

      final image = container.querySelector('img');
      final title = _cleanText(
        link.attributes['title'] ?? link.text,
      ).isNotEmpty
          ? _cleanText(link.attributes['title'] ?? link.text)
          : _cleanText(image?.attributes['alt'] ?? '');
      final resolvedUrl = _resolveUrl(baseUri, link.attributes['href'] ?? '');
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
          description: _cleanText(
            container.querySelector('.author')?.text ??
                container.querySelector('.desc')?.text ??
                '',
          ),
          coverUrl: _coverUrlForContainer(container, baseUri),
        ),
      );

      if (entriesByUrl.length >= 100) {
        break;
      }
    }
  }

  Future<ReadableWebContent> fetchReadableContent(String url) async {
    final body = await _get(url);
    final document = html_parser.parse(body);
    _removeNoisyNodes(document);

    final title = _firstCleanText(
      [
        document.querySelector('.chapter-title'),
        document.querySelector('#chapter h2'),
        document.querySelector('article h1'),
        document.querySelector('main h1'),
        document.querySelector('h1'),
        document.querySelector('title'),
      ],
    );
    final root = document.querySelector('#chapter-content') ??
        document.querySelector('#chr-content') ??
        document.querySelector('.chr-content') ??
        document.querySelector('.chapter-content') ??
        document.querySelector('.chapter-c') ??
        document.querySelector('article') ??
        document.querySelector('main') ??
        document.querySelector('[role="main"]') ??
        document.body;
    final text = root == null
        ? _cleanText(document.documentElement?.text ?? '')
        : _extractReadableText(root, title: title);

    return ReadableWebContent(
      title: title.isEmpty ? url : title,
      url: url,
      text: text,
    );
  }

  Future<List<WebChapterEntry>> fetchChapters(String url) async {
    final body = await _get(url);
    final baseUri = _parseHttpUri(url);
    final document = html_parser.parse(body);
    final chaptersByUrl = <String, WebChapterEntry>{};

    final ajaxChapterUrl = _ajaxChapterUrlFor(document, baseUri);
    if (ajaxChapterUrl != null) {
      final chapterBody = await _get(ajaxChapterUrl);
      final chapterDocument = html_parser.parse(chapterBody);
      _extractChapterOptions(
        document: chapterDocument,
        baseUri: baseUri,
        chaptersByUrl: chaptersByUrl,
      );
    }

    if (chaptersByUrl.isEmpty) {
      _removeNoisyNodes(document);
      _extractChapterOptions(
        document: document,
        baseUri: baseUri,
        chaptersByUrl: chaptersByUrl,
      );
      _extractChapterLinks(
        document: document,
        baseUri: baseUri,
        chaptersByUrl: chaptersByUrl,
      );
    }

    if (chaptersByUrl.isEmpty) {
      return [
        WebChapterEntry(
          title: 'Chapter 1',
          url: _withoutFragment(baseUri.toString()),
        ),
      ];
    }

    return chaptersByUrl.values.toList();
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

  String? _ajaxChapterUrlFor(dom.Document document, Uri baseUri) {
    final rating = document.querySelector('[data-novel-id]');
    final novelId = rating?.attributes['data-novel-id'];
    if (novelId == null || novelId.trim().isEmpty) {
      return null;
    }

    final body = document.outerHtml;
    final endpointMatch = RegExp(
      r"ajaxChapterOptionUrl\s*=\s*'([^']+)'",
    ).firstMatch(body);
    final endpoint = endpointMatch?.group(1) ?? 'ajax-chapter-option';
    final endpointUri = Uri.tryParse(endpoint);
    final resolvedEndpoint = endpointUri == null
        ? baseUri.resolve('ajax-chapter-option')
        : baseUri.resolveUri(endpointUri);

    return resolvedEndpoint.replace(
      queryParameters: {
        ...resolvedEndpoint.queryParameters,
        'novelId': novelId,
      },
    ).toString();
  }

  void _extractChapterOptions({
    required dom.Document document,
    required Uri baseUri,
    required Map<String, WebChapterEntry> chaptersByUrl,
  }) {
    for (final option in document.querySelectorAll('option[value]')) {
      final title = _cleanText(option.text);
      final resolvedUrl =
          _resolveUrl(baseUri, option.attributes['value'] ?? '');
      if (resolvedUrl == null || title.isEmpty) {
        continue;
      }

      final key = _withoutFragment(resolvedUrl);
      chaptersByUrl.putIfAbsent(
        key,
        () => WebChapterEntry(title: title, url: key),
      );
    }
  }

  void _extractChapterLinks({
    required dom.Document document,
    required Uri baseUri,
    required Map<String, WebChapterEntry> chaptersByUrl,
  }) {
    for (final link in document.querySelectorAll('a[href]')) {
      final href = link.attributes['href'] ?? '';
      final title = _cleanText(link.attributes['title'] ?? link.text);
      final normalized = '$href $title'.toLowerCase();
      if (!normalized.contains('chapter')) {
        continue;
      }

      final resolvedUrl = _resolveUrl(baseUri, href);
      if (resolvedUrl == null || title.isEmpty) {
        continue;
      }

      final key = _withoutFragment(resolvedUrl);
      chaptersByUrl.putIfAbsent(
        key,
        () => WebChapterEntry(title: title, url: key),
      );
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

  String? _coverUrlForContainer(dom.Element container, Uri baseUri) {
    final image = container.querySelector('img');
    final source = image?.attributes['src'] ??
        image?.attributes['data-src'] ??
        image?.attributes['data-cfsrc'];
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

  String _extractReadableText(dom.Element root, {required String title}) {
    for (final selector in const [
      '.chapter-nav',
      '.chapter-navigation',
      '.unlock-buttons',
      '.ads',
      '.adsbygoogle',
      '[class*="advert"]',
      '[id*="advert"]',
      '.translator',
      '.translation',
    ]) {
      for (final node in root.querySelectorAll(selector)) {
        node.remove();
      }
    }

    final paragraphs = root
        .querySelectorAll('p')
        .map((paragraph) => _cleanText(paragraph.text))
        .where((text) => text.isNotEmpty)
        .toList();

    if (paragraphs.isNotEmpty) {
      while (paragraphs.isNotEmpty &&
          _isLeadingChapterMetadata(paragraphs.first, title: title)) {
        paragraphs.removeAt(0);
      }
      return paragraphs.join('\n\n');
    }

    var text = _cleanText(root.text);
    if (_isLeadingChapterMetadata(text, title: title)) {
      text = '';
    }
    return text;
  }

  bool _isLeadingChapterMetadata(String text, {required String title}) {
    final normalized = _cleanText(text).toLowerCase();
    final normalizedTitle = _cleanText(title).toLowerCase();
    if (normalized.isEmpty ||
        (normalizedTitle.isNotEmpty && normalized == normalizedTitle)) {
      return true;
    }

    return RegExp(r'^chapter\s+(?:\d+|[ivxlcdm]+)\s*[:.\-]').hasMatch(
          normalized,
        ) ||
        RegExp(
          r'^(?:translator|translated by|translation|editor|edited by)\s*:',
        ).hasMatch(normalized) ||
        RegExp(r'^(?:prev(?:ious)? chapter|next chapter)(?:\s|$)').hasMatch(
          normalized,
        );
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
    return uri.removeFragment().toString();
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

class WebChapterEntry {
  const WebChapterEntry({
    required this.title,
    required this.url,
  });

  final String title;
  final String url;
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
