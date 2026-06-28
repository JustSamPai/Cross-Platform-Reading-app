import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../models/reading_document.dart';

class DocumentImporter {
  const DocumentImporter._();

  static Future<ReadingDocument?> pickDocument() async {
    final result = await FilePicker.pickFiles(
      type: FileType.any,
      withData: kIsWeb,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final file = result.files.first;
    final bytes = await readFileBytes(file);

    final documentType = ReadingDocumentType.fromFileName(file.name);
    final requiresBytes = documentType == ReadingDocumentType.pdf ||
        documentType == ReadingDocumentType.epub;
    if (requiresBytes && (bytes == null || bytes.isEmpty)) {
      throw DocumentImportException(
        'Android could not read ${file.name}. Try selecting it from local '
        'Downloads instead of a cloud-only location.',
      );
    }

    return ReadingDocument.fromPickedFile(
      fileName: file.name,
      bytes: bytes,
      filePath: file.path,
    );
  }

  @visibleForTesting
  static Future<Uint8List?> readFileBytes(PlatformFile file) async {
    Uint8List? bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      try {
        bytes = await file.xFile.readAsBytes();
      } catch (_) {
        bytes = null;
      }
    }
    return bytes;
  }
}

class DocumentImportException implements Exception {
  const DocumentImportException(this.message);

  final String message;

  @override
  String toString() => message;
}
