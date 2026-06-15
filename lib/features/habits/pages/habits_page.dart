import 'package:flutter/material.dart';

import '../models/reading_habit.dart';

class HabitsPage extends StatelessWidget {
  const HabitsPage({super.key});

  static const habits = [
    ReadingHabit(
      name: 'Read technical book',
      currentStreak: 5,
      targetMinutes: 25,
      completedToday: true,
    ),
    ReadingHabit(
      name: 'Review notes',
      currentStreak: 3,
      targetMinutes: 10,
      completedToday: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reading Habits')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Streaks',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          for (final habit in habits)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Icon(
                  habit.completedToday
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                ),
                title: Text(habit.name),
                subtitle: Text('${habit.targetMinutes} min target'),
                trailing: Text('${habit.currentStreak} days'),
              ),
            ),
        ],
      ),
    );
  }
}
