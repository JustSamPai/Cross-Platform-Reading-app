import 'package:flutter_reading_portfolio_app/features/library/data/web_content_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('extracts source entries from links', () async {
    final client = WebContentClient(
      client: MockClient((request) async {
        return http.Response(
          '''
          <html>
            <body>
              <nav><a href="/login">Login</a></nav>
              <main>
                <a href="/novels/demo">
                  <img src="/covers/demo.jpg">
                  Demo Novel
                </a>
                <a href="https://example.com/novels/second">Second Story</a>
              </main>
            </body>
          </html>
          ''',
          200,
        );
      }),
    );

    final entries = await client.fetchEntries(
      url: 'https://example.com',
      sourceName: 'Example Source',
    );

    expect(entries.map((entry) => entry.title), contains('Demo Novel'));
    expect(entries.first.url, startsWith('https://example.com/novels/'));
    expect(entries.first.coverUrl, 'https://example.com/covers/demo.jpg');
  });

  test('extracts readable content', () async {
    final client = WebContentClient(
      client: MockClient((request) async {
        return http.Response(
          '''
          <html>
            <head><title>Fallback Title</title></head>
            <body>
              <header>Navigation</header>
              <article>
                <h1>Chapter One</h1>
                <p>The first line.</p>
                <p>The second line.</p>
              </article>
            </body>
          </html>
          ''',
          200,
        );
      }),
    );

    final content = await client.fetchReadableContent(
      'https://example.com/novels/demo/chapter-1',
    );

    expect(content.title, 'Chapter One');
    expect(content.text, contains('The first line.'));
    expect(content.text, isNot(contains('Navigation')));
  });
}
