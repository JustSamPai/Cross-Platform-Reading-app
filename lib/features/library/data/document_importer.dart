import 'package:file_picker/file_picker.dart';

import '../models/reading_document.dart';

class DocumentImporter {
  const DocumentImporter._();

  static Future<ReadingDocument?> pickDocument() async {
    final result = await FilePicker.pickFiles(
      type: FileType.any,
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final file = result.files.first;
    return ReadingDocument.fromPickedFile(
      fileName: file.name,
      bytes: file.bytes,
      filePath: file.path,
    );
  }
}
