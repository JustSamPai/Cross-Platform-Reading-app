import 'package:flutter/material.dart';

import '../../habits/pages/habits_page.dart';
import '../../pdf/pages/pdf_reader_page.dart';
import '../../quiz/pages/quiz_page.dart';
import '../data/sample_books.dart';
import '../models/book.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedIndex = 0;

  final pages = const [
    _LibraryDashboard(),
    HabitsPage(),
    QuizPage(),
    PdfReaderPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() => selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_fire_department_outlined),
            selectedIcon: Icon(Icons.local_fire_department),
            label: 'Habits',
          ),
          NavigationDestination(
            icon: Icon(Icons.quiz_outlined),
            selectedIcon: Icon(Icons.quiz),
            label: 'Quiz',
          ),
          NavigationDestination(
            icon: Icon(Icons.picture_as_pdf_outlined),
            selectedIcon: Icon(Icons.picture_as_pdf),
            label: 'PDF',
          ),
        ],
      ),
    );
  }
}

class _LibraryDashboard extends StatelessWidget {
  const _LibraryDashboard();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reading Dashboard'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Continue Reading',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          for (final book in sampleBooks) BookProgressCard(book: book),
        ],
      ),
    );
  }
}

class BookProgressCard extends StatelessWidget {
  const BookProgressCard({required this.book, super.key});

  final Book book;

  @override
  Widget build(BuildContext context) {
    final progressPercent = (book.progress * 100).round();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              book.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(book.author),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: book.progress),
            const SizedBox(height: 8),
            Text('$progressPercent% complete'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final tag in book.tags) Chip(label: Text(tag)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
