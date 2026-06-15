import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app/reading_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('reading_app');

  runApp(const ReadingApp());
}
