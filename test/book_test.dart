import 'package:flutter_reading_portfolio_app/features/library/models/book.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('progress exposes bounded values for display', () {
    const book = Book(
      title: 'Example',
      author: 'Reader',
      totalPages: 100,
      currentPage: 125,
      tags: ['Test'],
    );

    expect(book.progress, 1);
    expect(book.progressPercent, 100);
    expect(book.remainingPages, 0);
  });

  test('progress handles empty books safely', () {
    const book = Book(
      title: 'Empty',
      author: 'Reader',
      totalPages: 0,
      currentPage: 0,
      tags: ['Test'],
    );

    expect(book.progress, 0);
    expect(book.progressPercent, 0);
    expect(book.remainingPages, 0);
  });
}
