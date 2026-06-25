import 'package:flutter/material.dart';
import 'package:flutter_reading_portfolio_app/features/quiz/data/sample_questions.dart';
import 'package:flutter_reading_portfolio_app/features/quiz/pages/quiz_view_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('moves through quiz questions after an answer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: QuizViewPage(deck: sampleQuizDecks.first),
      ),
    );
    await tester.pump();

    expect(find.text('Question 1'), findsOneWidget);
    expect(find.text('It improves recall'), findsOneWidget);

    await tester.tap(find.text('It improves recall'));
    await tester.pump();

    expect(find.text('Question 2'), findsOneWidget);
    expect(find.text('Returning to important ideas over time'), findsOneWidget);
  });
}
