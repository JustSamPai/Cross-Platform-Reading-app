import 'package:flutter/material.dart';

import '../../../core/widgets/page_frame.dart';
import '../data/reading_habit_store.dart';
import '../data/reading_xp_store.dart';
import '../models/reading_habit.dart';
import '../widgets/habit_heat_map.dart';

class HabitsPage extends StatefulWidget {
  const HabitsPage({super.key});

  @override
  State<HabitsPage> createState() => _HabitsPageState();
}

class _HabitsPageState extends State<HabitsPage> {
  final store = ReadingHabitStore();
  final xpStore = ReadingXpStore();
  List<ReadingHabit> habits = const [];
  Map<DateTime, int> heatMapDataset = const {};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final xpProgress = xpStore.load();
    final completedCount = habits.where((habit) => habit.completedToday).length;
    final plannedMinutes = habits.fold<int>(
      0,
      (total, habit) => total + habit.targetMinutes,
    );

    return PageFrame(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Habits',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
              ),
              FilledButton.icon(
                onPressed: () => _showHabitDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add habit'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _HabitOverviewCard(
            completedCount: completedCount,
            habitCount: habits.length,
            plannedMinutes: plannedMinutes,
          ),
          const SizedBox(height: 12),
          _ReadingXpCard(progress: xpProgress),
          const SizedBox(height: 12),
          HabitHeatMap(
            dataset: heatMapDataset,
            startDate: store.startDate,
          ),
          const SizedBox(height: 28),
          Text(
            'Daily targets',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          if (habits.isEmpty)
            const Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Add a reading habit to start tracking today.'),
              ),
            )
          else
            for (var index = 0; index < habits.length; index++)
              _HabitCard(
                habit: habits[index],
                onChanged: (value) => _toggleHabit(index, value ?? false),
                onEdit: () =>
                    _showHabitDialog(index: index, habit: habits[index]),
                onDelete: () => _deleteHabit(index),
              ),
        ],
      ),
    );
  }

  void _reload() {
    store.ensureInitialized();
    setState(() {
      habits = store.loadToday();
      heatMapDataset = store.heatMapDataset();
    });
  }

  void _toggleHabit(int index, bool completed) {
    setState(() {
      habits = store.toggleHabit(index, completed);
      heatMapDataset = store.heatMapDataset();
    });
  }

  void _deleteHabit(int index) {
    setState(() {
      habits = store.deleteHabit(index);
      heatMapDataset = store.heatMapDataset();
    });
  }

  Future<void> _showHabitDialog({
    int? index,
    ReadingHabit? habit,
  }) async {
    final nameController = TextEditingController(text: habit?.name ?? '');
    final minutesController = TextEditingController(
      text: (habit?.targetMinutes ?? 20).toString(),
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(index == null ? 'New habit' : 'Edit habit'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Habit name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: minutesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Target minutes'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    final habitName = nameController.text;
    final targetMinutes = int.tryParse(minutesController.text) ?? 20;
    nameController.dispose();
    minutesController.dispose();

    if (saved != true) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      habits = index == null
          ? store.addHabit(habitName, targetMinutes)
          : store.updateHabit(index, habitName, targetMinutes);
      heatMapDataset = store.heatMapDataset();
    });
  }
}

class _ReadingXpCard extends StatelessWidget {
  const _ReadingXpCard({required this.progress});

  final ReadingXpProgress progress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: colorScheme.tertiary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Reading level ${progress.currentLevel}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text(
                  '${progress.currentXp} / '
                  '${progress.xpNeededForNextLevel} XP',
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: progress.levelProgress,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${progress.pagesRead} pages read  |  '
              '${progress.completedBooks} books completed  |  '
              '${progress.totalXp} total XP',
            ),
          ],
        ),
      ),
    );
  }
}

class _HabitOverviewCard extends StatelessWidget {
  const _HabitOverviewCard({
    required this.completedCount,
    required this.habitCount,
    required this.plannedMinutes,
  });

  final int completedCount;
  final int habitCount;
  final int plannedMinutes;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.task_alt,
              color: colorScheme.primary,
              size: 36,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$completedCount of $habitCount complete',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text('$plannedMinutes focused minutes planned today'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HabitCard extends StatelessWidget {
  const _HabitCard({
    required this.habit,
    required this.onChanged,
    required this.onEdit,
    required this.onDelete,
  });

  final ReadingHabit habit;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor =
        habit.completedToday ? colorScheme.primary : colorScheme.outline;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Checkbox(
          value: habit.completedToday,
          onChanged: onChanged,
        ),
        title: Text(habit.name),
        subtitle: Text('${habit.targetMinutes} min target'),
        trailing: Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '${habit.currentStreak}d',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: statusColor,
                  ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Habit actions',
              onSelected: (value) {
                if (value == 'edit') {
                  onEdit();
                }
                if (value == 'delete') {
                  onDelete();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Text('Edit'),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
