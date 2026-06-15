import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/library/pages/home_page.dart';

class ReadingApp extends StatelessWidget {
  const ReadingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reading Habit App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const HomePage(),
    );
  }
}
