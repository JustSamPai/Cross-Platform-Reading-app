import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/storage/reading_storage.dart';
import '../../../core/widgets/page_frame.dart';
import '../../habits/data/reading_habit_store.dart';
import '../../habits/pages/habits_page.dart';
import '../../pdf/pages/pdf_reader_page.dart';
import '../data/library_store.dart';
import '../../quiz/pages/quiz_page.dart';
import '../data/sample_books.dart';
import '../models/book.dart';
import '../models/reading_document.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedIndex = 0;

  static const _pages = [
    _LibraryDashboard(),
    HabitsPage(),
    QuizPage(),
    PdfReaderPage(),
  ];

  static const _destinations = [
    _AppDestination(
      label: 'Library',
      icon: Icons.menu_book_outlined,
      selectedIcon: Icons.menu_book,
    ),
    _AppDestination(
      label: 'Habits',
      icon: Icons.local_fire_department_outlined,
      selectedIcon: Icons.local_fire_department,
    ),
    _AppDestination(
      label: 'Quiz',
      icon: Icons.quiz_outlined,
      selectedIcon: Icons.quiz,
    ),
    _AppDestination(
      label: 'PDF',
      icon: Icons.picture_as_pdf_outlined,
      selectedIcon: Icons.picture_as_pdf,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final useRail = MediaQuery.sizeOf(context).width >= 800;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ReadFlow'),
      ),
      body: Row(
        children: [
          if (useRail)
            NavigationRail(
              selectedIndex: selectedIndex,
              extended: MediaQuery.sizeOf(context).width >= 1040,
              onDestinationSelected: _selectDestination,
              destinations: [
                for (final destination in _destinations)
                  NavigationRailDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
                    label: Text(destination.label),
                  ),
              ],
            ),
          Expanded(
            child: SafeArea(
              top: false,
              child: IndexedStack(
                index: selectedIndex,
                children: _pages,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: useRail
          ? null
          : NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: _selectDestination,
              destinations: [
                for (final destination in _destinations)
                  NavigationDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
                    label: destination.label,
                  ),
              ],
            ),
    );
  }

  void _selectDestination(int index) {
    setState(() => selectedIndex = index);
  }
}

class _AppDestination {
  const _AppDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _LibraryDashboard extends StatefulWidget {
  const _LibraryDashboard();

  @override
  State<_LibraryDashboard> createState() => _LibraryDashboardState();
}

class _LibraryDashboardState extends State<_LibraryDashboard> {
  @override
  void initState() {
    super.initState();
    ReadingHabitStore().ensureInitialized();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<dynamic>>(
      valueListenable: ReadingStorage.box.listenable(),
      builder: (context, box, _) {
        final habitStore = ReadingHabitStore(box: box);
        final habits = habitStore.loadToday();
        final documents = LibraryStore(box: box).documents();
        final completedHabits =
            habits.where((habit) => habit.completedToday).length;
        final totalPagesRead = sampleBooks.fold<int>(
          0,
          (total, book) => total + book.currentPage,
        );
        final longestStreak = habits.fold<int>(
          0,
          (longest, habit) =>
              habit.currentStreak > longest ? habit.currentStreak : longest,
        );

        return PageFrame(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Today',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 16),
              _StatGrid(
                stats: [
                  _DashboardStat(
                    icon: Icons.auto_stories_outlined,
                    label: 'Active books',
                    value: '${sampleBooks.length}',
                    detail: '$totalPagesRead pages logged',
                  ),
                  _DashboardStat(
                    icon: Icons.check_circle_outline,
                    label: 'Habits done',
                    value: '$completedHabits/${habits.length}',
                    detail: 'Targets completed',
                  ),
                  _DashboardStat(
                    icon: Icons.folder_copy_outlined,
                    label: 'Documents',
                    value: '${documents.length}',
                    detail: 'PDF / EPUB imports',
                  ),
                  _DashboardStat(
                    icon: Icons.local_fire_department_outlined,
                    label: 'Best streak',
                    value: '$longestStreak days',
                    detail: 'Current habit streak',
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                'Continue reading',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              for (final book in sampleBooks) BookProgressCard(book: book),
              const SizedBox(height: 16),
              Text(
                'Imported documents',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              if (documents.isEmpty)
                const Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Import PDFs or EPUBs from the PDF tab.'),
                  ),
                )
              else
                for (final document in documents.take(3))
                  _ImportedDocumentCard(document: document),
            ],
          ),
        );
      },
    );
  }
}

class _ImportedDocumentCard extends StatelessWidget {
  const _ImportedDocumentCard({required this.document});

  final ReadingDocument document;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          document.type == ReadingDocumentType.epub
              ? Icons.menu_book_outlined
              : Icons.picture_as_pdf_outlined,
        ),
        title: Text(document.title),
        subtitle: Text(document.type.label),
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.stats});

  final List<_DashboardStat> stats;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cardWidth = width >= 720
            ? (width - 24) / 3
            : width >= 520
                ? (width - 12) / 2
                : width;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final stat in stats)
              SizedBox(
                width: cardWidth,
                child: _MetricCard(stat: stat),
              ),
          ],
        );
      },
    );
  }
}

class _DashboardStat {
  const _DashboardStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.stat});

  final _DashboardStat stat;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  stat.icon,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stat.label,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stat.value,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    stat.detail,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BookProgressCard extends StatelessWidget {
  const BookProgressCard({required this.book, super.key});

  final Book book;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(book.title, style: textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(book.author),
                    ],
                  ),
                ),
                Text(
                  '${book.progressPercent}%',
                  style: textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: book.progress,
              ),
            ),
            const SizedBox(height: 8),
            Text(
                '${book.currentPage} / ${book.totalPages} pages - ${book.remainingPages} left'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
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
