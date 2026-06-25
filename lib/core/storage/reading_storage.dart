import 'package:hive_flutter/hive_flutter.dart';

class ReadingStorage {
  const ReadingStorage._();

  static const boxName = 'readflow_storage';

  static Future<void> initialize() async {
    await Hive.initFlutter();
    await Hive.openBox(boxName);
  }

  static Box<dynamic> get box => Hive.box<dynamic>(boxName);
}
