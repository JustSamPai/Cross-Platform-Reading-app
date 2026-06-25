import 'package:flutter/material.dart';

import 'app/reading_app.dart';
import 'core/storage/reading_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ReadingStorage.initialize();

  runApp(const ReadingApp());
}
