import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/storage/reading_storage.dart';
import '../../../core/widgets/page_frame.dart';
import '../../extensions/pages/extensions_page.dart';
import '../../habits/data/reading_habit_store.dart';
import '../../habits/pages/habits_page.dart';
import '../../pdf/pages/book_progress_page.dart';
import '../../pdf/pages/document_reader_page.dart';
import '../../pdf/pages/epub_reader_page.dart';
import '../../pdf/pages/pdf_reader_page.dart';
import '../data/document_importer.dart';
import '../data/library_store.dart';
import '../../quiz/pages/quiz_page.dart';
import '../../settings/pages/settings_page.dart';
import '../models/reading_document.dart';
import 'novel_stats_page.dart';

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
    ExtensionsPage(),
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
    _AppDestination(
      label: 'Extensions',
      icon: Icons.extension_outlined,
      selectedIcon: Icons.extension,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final useRail = MediaQuery.sizeOf(context).width >= 800;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ReadFlow'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
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

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsPage()),
    );
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
  final titleController = TextEditingController();
  final authorController = TextEditingController();
  final totalPagesController = TextEditingController();
  final currentPageController = TextEditingController(text: '0');

  @override
  void initState() {
    super.initState();
    ReadingHabitStore().ensureInitialized();
  }

  @override
  void dispose() {
    titleController.dispose();
    authorController.dispose();
    totalPagesController.dispose();
    currentPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<dynamic>>(
      valueListenable: ReadingStorage.box.listenable(),
      builder: (context, box, _) {
        final habitStore = ReadingHabitStore(box: box);
        final libraryStore = LibraryStore(box: box);
        final habits = habitStore.loadToday();
        final documents = libraryStore.documents();
        final completedHabits =
            habits.where((habit) => habit.completedToday).length;
        final totalPagesRead = documents.fold<int>(
          0,
          (total, document) =>
              total +
              (document.type == ReadingDocumentType.webNovel
                  ? document.readChapterUrls.length
                  : document.lastPageNumber),
        );
        final inProgressCount = documents.where((document) {
          return document.progress > 0 && document.progress < 1;
        }).length;
        final completedCount = documents.where((document) {
          return document.progress >= 1 && document.pageCount > 0;
        }).length;
        final importCount = documents.where((document) {
          return document.type != ReadingDocumentType.book &&
              document.type != ReadingDocumentType.webNovel;
        }).length;
        final manualBookCount = documents.where((document) {
          return document.type == ReadingDocumentType.book;
        }).length;
        final webNovelCount = documents.where((document) {
          return document.type == ReadingDocumentType.webNovel;
        }).length;
        final mostRecent = documents.fold<DateTime?>(
          null,
          (latest, document) {
            final openedAt = document.lastOpenedAt ?? document.addedAt;
            if (latest == null || openedAt.isAfter(latest)) {
              return openedAt;
            }
            return latest;
          },
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
                'Library',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _importDocument,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Import file'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _openAddBookDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add book'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _StatGrid(
                stats: [
                  _DashboardStat(
                    icon: Icons.auto_stories_outlined,
                    label: 'Library items',
                    value: '${documents.length}',
                    detail:
                        '$manualBookCount books / $webNovelCount web / $importCount files',
                  ),
                  _DashboardStat(
                    icon: Icons.timeline_outlined,
                    label: 'Pages logged',
                    value: '$totalPagesRead',
                    detail: '$inProgressCount in progress',
                  ),
                  _DashboardStat(
                    icon: Icons.check_circle_outline,
                    label: 'Completed',
                    value: '$completedCount',
                    detail: mostRecent == null
                        ? 'No reading yet'
                        : 'Recent activity saved',
                  ),
                  _DashboardStat(
                    icon: Icons.local_fire_department_outlined,
                    label: 'Best streak',
                    value: '$longestStreak days',
                    detail: '$completedHabits/${habits.length} habits today',
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                'Your books and files',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              if (documents.isEmpty)
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                            'Add a book or import a file to start your library.'),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: _importDocument,
                              icon: const Icon(Icons.upload_file),
                              label: const Text('Import file'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _openAddBookDialog,
                              icon: const Icon(Icons.add),
                              label: const Text('Add book'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
              else
                for (final document in documents)
                  _LibraryDocumentCard(
                    document: document,
                    onOpen: () => _openDocument(document),
                    onDelete: () => _deleteDocument(document),
                  ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _importDocument() async {
    ReadingDocument? document;
    try {
      document = await DocumentImporter.pickDocument();
    } on DocumentImportException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
      return;
    }
    if (document == null || !mounted) {
      return;
    }
    final importedDocument = document;

    final documents = LibraryStore().addDocument(importedDocument);
    final storedDocument = documents.firstWhere(
      (stored) =>
          (importedDocument.filePath != null &&
              stored.filePath == importedDocument.filePath) ||
          (importedDocument.filePath == null &&
              stored.title == importedDocument.title &&
              stored.type == importedDocument.type),
      orElse: () => importedDocument,
    );

    if (mounted) {
      await _openDocument(storedDocument);
    }
  }

  Future<void> _openDocument(ReadingDocument document) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return switch (document.type) {
            ReadingDocumentType.pdf => DocumentReaderPage(document: document),
            ReadingDocumentType.epub => EpubReaderPage(document: document),
            ReadingDocumentType.webNovel => NovelStatsPage(document: document),
            ReadingDocumentType.book ||
            ReadingDocumentType.other =>
              BookProgressPage(document: document),
          };
        },
      ),
    );
  }

  void _deleteDocument(ReadingDocument document) {
    LibraryStore().deleteDocument(document.id);
  }

  void _openAddBookDialog() {
    titleController.clear();
    authorController.clear();
    totalPagesController.clear();
    currentPageController.text = '0';

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add book'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: authorController,
                  decoration: const InputDecoration(labelText: 'Author'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: currentPageController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Current page',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: totalPagesController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Total pages',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: _saveManualBook,
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _saveManualBook() {
    final title = titleController.text.trim();
    if (title.isEmpty) {
      return;
    }

    final totalPages = int.tryParse(totalPagesController.text.trim()) ?? 0;
    final currentPage = int.tryParse(currentPageController.text.trim()) ?? 0;
    LibraryStore().addDocument(
      ReadingDocument.manualBook(
        title: title,
        author: authorController.text.trim(),
        totalPages: totalPages,
        currentPage: currentPage,
      ),
    );
    Navigator.pop(context);
  }
}

class _LibraryDocumentCard extends StatelessWidget {
  const _LibraryDocumentCard({
    required this.document,
    required this.onOpen,
    required this.onDelete,
  });

  final ReadingDocument document;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final novelTierColor = _novelTierColor(document.novelReadingTier);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: novelTierColor?.withValues(alpha: 0.1),
      shape: novelTierColor == null
          ? null
          : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: novelTierColor, width: 1.5),
            ),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LibraryDocumentVisual(
                    document: document,
                    fallbackIcon: _iconFor(document.type),
                    accentColor: novelTierColor ?? colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          document.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (document.author != null) Text(document.author!),
                        Text(
                            '${document.type.label} - ${document.progressLabel}'),
                        if (document.type == ReadingDocumentType.webNovel &&
                            document.readChapterUrls.isNotEmpty)
                          Text(
                            '${document.readChapterUrls.length} chapters read',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(color: novelTierColor),
                          ),
                      ],
                    ),
                  ),
                  Text('${document.progressPercent}%'),
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: document.progress,
                  color: novelTierColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(ReadingDocumentType type) {
    return switch (type) {
      ReadingDocumentType.pdf => Icons.picture_as_pdf_outlined,
      ReadingDocumentType.epub => Icons.menu_book_outlined,
      ReadingDocumentType.webNovel => Icons.public,
      ReadingDocumentType.book => Icons.auto_stories_outlined,
      ReadingDocumentType.other => Icons.insert_drive_file_outlined,
    };
  }

  Color? _novelTierColor(NovelReadingTier tier) {
    return switch (tier) {
      NovelReadingTier.none => null,
      NovelReadingTier.green => const Color(0xFF2E7D32),
      NovelReadingTier.blue => const Color(0xFF1565C0),
      NovelReadingTier.gold => const Color(0xFFB77900),
      NovelReadingTier.purple => const Color(0xFF7B1FA2),
    };
  }
}

class _LibraryDocumentVisual extends StatelessWidget {
  const _LibraryDocumentVisual({
    required this.document,
    required this.fallbackIcon,
    required this.accentColor,
  });

  final ReadingDocument document;
  final IconData fallbackIcon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final coverUrl = document.coverUrl;

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: SizedBox(
          width: 52,
          height: 76,
          child: coverUrl == null || coverUrl.isEmpty
              ? Icon(fallbackIcon, color: accentColor)
              : Padding(
                  padding: const EdgeInsets.all(3),
                  child: Image.network(
                    coverUrl,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(fallbackIcon, color: accentColor);
                    },
                  ),
                ),
        ),
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
