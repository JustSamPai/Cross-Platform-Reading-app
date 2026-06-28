import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_reading_portfolio_app/features/library/data/document_importer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads native picked-file data when bytes are not preloaded', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'readflow_import_test_',
    );
    addTearDown(() => tempDirectory.delete(recursive: true));

    final file = File('${tempDirectory.path}/sample.epub');
    await file.writeAsBytes([80, 75, 3, 4]);
    final pickedFile = PlatformFile(
      name: 'sample.epub',
      size: await file.length(),
      path: file.path,
    );

    final bytes = await DocumentImporter.readFileBytes(pickedFile);

    expect(bytes, [80, 75, 3, 4]);
  });
}
