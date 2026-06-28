import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/storage/reading_storage.dart';
import '../../pdf/pages/web_novel_chapters_page.dart';
import '../data/library_store.dart';
import '../models/reading_document.dart';

class NovelStatsPage extends StatelessWidget {
  const NovelStatsPage({required this.document, super.key});

  final ReadingDocument document;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Novel stats')),
      body: ValueListenableBuilder<Box<dynamic>>(
        valueListenable: ReadingStorage.box.listenable(),
        builder: (context, box, child) {
          final store = LibraryStore(box: box);
          final currentDocument = store.documents().firstWhere(
                (stored) => stored.id == document.id,
                orElse: () => document,
              );
          return _NovelStatsContent(document: currentDocument);
        },
      ),
    );
  }
}

class _NovelStatsContent extends StatelessWidget {
  const _NovelStatsContent({required this.document});

  final ReadingDocument document;

  @override
  Widget build(BuildContext context) {
    final tier = document.novelReadingTier;
    final tierColor = _tierColor(tier);
    final target = document.nextNovelTierChapterTarget;
    final chaptersNeeded = document.chaptersToNextNovelTier;
    final secondsNeeded = document.readingSecondsToNextNovelTier(
      secondsPerChapter: LibraryStore.minimumChapterReadSeconds,
    );
    final tierStart = _tierStart(tier);
    final tierProgress = target == null
        ? 1.0
        : ((document.readChapterUrls.length - tierStart) / (target - tierStart))
            .clamp(0, 1)
            .toDouble();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 840),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              document.title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            if (document.author != null) ...[
              const SizedBox(height: 4),
              Text(document.author!),
            ],
            if (document.sourceName != null) ...[
              const SizedBox(height: 4),
              Text(document.sourceName!),
            ],
            const SizedBox(height: 20),
            _TierTrack(currentTier: tier),
            const SizedBox(height: 20),
            Card(
              margin: EdgeInsets.zero,
              color: tierColor.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: tierColor),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_tierLabel(tier)} stage',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: tierColor,
                          ),
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      minHeight: 10,
                      value: tierProgress,
                      color: tierColor,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      target == null
                          ? 'Highest novel stage reached'
                          : '$chaptersNeeded qualifying chapters and about '
                              '${_formatDuration(secondsNeeded)} remain to reach '
                              '${_nextTierLabel(tier)}.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = constraints.maxWidth >= 620
                    ? (constraints.maxWidth - 24) / 3
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _StatCard(
                      width: itemWidth,
                      icon: Icons.menu_book_outlined,
                      value: '${document.readChapterUrls.length}',
                      label: 'Chapters read',
                    ),
                    _StatCard(
                      width: itemWidth,
                      icon: Icons.timer_outlined,
                      value: _formatDuration(document.readingSeconds),
                      label: 'Time spent reading',
                    ),
                    _StatCard(
                      width: itemWidth,
                      icon: Icons.flag_outlined,
                      value: target == null ? 'Complete' : '$target',
                      label: target == null
                          ? 'Tier progression'
                          : 'Next stage target',
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        WebNovelChaptersPage(document: document),
                  ),
                ),
                icon: const Icon(Icons.chrome_reader_mode_outlined),
                label: const Text('Continue reading'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TierTrack extends StatelessWidget {
  const _TierTrack({required this.currentTier});

  final NovelReadingTier currentTier;

  @override
  Widget build(BuildContext context) {
    const tiers = [
      NovelReadingTier.green,
      NovelReadingTier.blue,
      NovelReadingTier.gold,
      NovelReadingTier.purple,
    ];
    final currentIndex = tiers.indexOf(currentTier);

    return Row(
      children: [
        for (var index = 0; index < tiers.length; index++) ...[
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: index <= currentIndex
                        ? _tierColor(tiers[index])
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _tierLabel(tiers[index]),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
          if (index < tiers.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.width,
    required this.icon,
    required this.value,
    required this.label,
  });

  final double width;
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value, style: Theme.of(context).textTheme.titleLarge),
                    Text(label),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

int _tierStart(NovelReadingTier tier) {
  return switch (tier) {
    NovelReadingTier.none => 0,
    NovelReadingTier.green => 1,
    NovelReadingTier.blue => 10,
    NovelReadingTier.gold => 50,
    NovelReadingTier.purple => 100,
  };
}

String _tierLabel(NovelReadingTier tier) {
  return switch (tier) {
    NovelReadingTier.none => 'Unranked',
    NovelReadingTier.green => 'Green',
    NovelReadingTier.blue => 'Blue',
    NovelReadingTier.gold => 'Gold',
    NovelReadingTier.purple => 'Purple',
  };
}

String _nextTierLabel(NovelReadingTier tier) {
  return switch (tier) {
    NovelReadingTier.none => 'Green',
    NovelReadingTier.green => 'Blue',
    NovelReadingTier.blue => 'Gold',
    NovelReadingTier.gold => 'Purple',
    NovelReadingTier.purple => 'Purple',
  };
}

Color _tierColor(NovelReadingTier tier) {
  return switch (tier) {
    NovelReadingTier.none => const Color(0xFF616161),
    NovelReadingTier.green => const Color(0xFF2E7D32),
    NovelReadingTier.blue => const Color(0xFF1565C0),
    NovelReadingTier.gold => const Color(0xFFB77900),
    NovelReadingTier.purple => const Color(0xFF7B1FA2),
  };
}

String _formatDuration(int totalSeconds) {
  if (totalSeconds < 60) {
    return '$totalSeconds sec';
  }
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  if (hours == 0) {
    return '$minutes min';
  }
  return minutes == 0 ? '$hours hr' : '$hours hr $minutes min';
}
