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

  test('extracts structured novel rows with covers', () async {
    final client = WebContentClient(
      client: MockClient((request) async {
        return http.Response(
          '''
          <html>
            <body>
              <div class="archive">
                <div class="row">
                  <div><img src="/uploads/thumbs/hidden.jpg" class="cover" alt="Hidden Marriage"></div>
                  <div>
                    <h3 class="truyen-title">
                      <a href="/hidden-marriage.html" title="Hidden Marriage">Hidden Marriage</a>
                    </h3>
                    <span class="author">Jiong Jiong You Yao</span>
                  </div>
                  <div>
                    <a href="/hidden-marriage/chapter-1.html" title="Chapter 1">Chapter 1</a>
                  </div>
                </div>
              </div>
            </body>
          </html>
          ''',
          200,
        );
      }),
    );

    final entries = await client.fetchEntries(
      url: 'https://novgo.net/most-popular?page=1',
      sourceName: 'NOVGO',
    );

    expect(entries, hasLength(1));
    expect(entries.single.title, 'Hidden Marriage');
    expect(entries.single.url, 'https://novgo.net/hidden-marriage.html');
    expect(
        entries.single.coverUrl, 'https://novgo.net/uploads/thumbs/hidden.jpg');
    expect(entries.single.description, 'Jiong Jiong You Yao');
  });

  test('extracts chapters from ajax chapter options', () async {
    final client = WebContentClient(
      client: MockClient((request) async {
        if (request.url.path.contains('ajax-chapter-option')) {
          return http.Response(
            '''
            <select>
              <option value="/hidden-marriage/chapter-1.html">Chapter 1</option>
              <option value="/hidden-marriage/chapter-2.html">Chapter 2</option>
            </select>
            ''',
            200,
          );
        }

        return http.Response(
          '''
          <html>
            <head>
              <script>
                var ajaxChapterOptionUrl = 'https://novgo.net/ajax-chapter-option';
              </script>
            </head>
            <body>
              <div id="rating" data-novel-id="184"></div>
            </body>
          </html>
          ''',
          200,
        );
      }),
    );

    final chapters = await client.fetchChapters(
      'https://novgo.net/hidden-marriage.html',
    );

    expect(chapters, hasLength(2));
    expect(chapters.first.title, 'Chapter 1');
    expect(
      chapters.first.url,
      'https://novgo.net/hidden-marriage/chapter-1.html',
    );
  });
}
