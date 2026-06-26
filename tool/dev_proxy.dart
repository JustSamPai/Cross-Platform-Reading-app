import 'dart:io';

Future<void> main(List<String> args) async {
  final port = args.isNotEmpty ? int.tryParse(args.first) ?? 8787 : 8787;
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 20)
    ..userAgent =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/126.0 Safari/537.36';

  stdout.writeln('ReadFlow dev proxy listening on http://127.0.0.1:$port');
  stdout.writeln('Fetch endpoint: http://127.0.0.1:$port/fetch?url=<url>');

  await for (final request in server) {
    _setCorsHeaders(request.response);

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      continue;
    }

    if (request.method != 'GET' || request.uri.path != '/fetch') {
      await _writeError(
        request.response,
        HttpStatus.notFound,
        'Use /fetch?url=<http-url>',
      );
      continue;
    }

    final target = request.uri.queryParameters['url'];
    final targetUri = target == null ? null : Uri.tryParse(target);
    if (targetUri == null ||
        targetUri.host.isEmpty ||
        (targetUri.scheme != 'http' && targetUri.scheme != 'https')) {
      await _writeError(
        request.response,
        HttpStatus.badRequest,
        'Missing or invalid url query parameter',
      );
      continue;
    }

    try {
      final upstreamRequest = await client.getUrl(targetUri);
      upstreamRequest.headers
        ..set(HttpHeaders.acceptHeader,
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8')
        ..set(HttpHeaders.acceptLanguageHeader, 'en-US,en;q=0.9')
        ..set(HttpHeaders.refererHeader, targetUri.origin);

      final upstreamResponse = await upstreamRequest.close();
      request.response.statusCode = upstreamResponse.statusCode;

      final contentType = upstreamResponse.headers.contentType;
      if (contentType != null) {
        request.response.headers.contentType = contentType;
      }

      await upstreamResponse.pipe(request.response);
    } catch (error) {
      await _writeError(
        request.response,
        HttpStatus.badGateway,
        'Proxy fetch failed: $error',
      );
    }
  }
}

void _setCorsHeaders(HttpResponse response) {
  response.headers
    ..set(HttpHeaders.accessControlAllowOriginHeader, '*')
    ..set(HttpHeaders.accessControlAllowMethodsHeader, 'GET, OPTIONS')
    ..set(HttpHeaders.accessControlAllowHeadersHeader, 'Content-Type, Accept')
    ..set(HttpHeaders.cacheControlHeader, 'no-store');
}

Future<void> _writeError(
  HttpResponse response,
  int statusCode,
  String message,
) async {
  response.statusCode = statusCode;
  response.headers.contentType = ContentType.text;
  response.write(message);
  await response.close();
}
