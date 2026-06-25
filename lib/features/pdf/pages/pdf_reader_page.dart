import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/page_frame.dart';
import '../../library/data/library_store.dart';
import '../../library/models/reading_document.dart';
import 'document_reader_page.dart';

class PdfReaderPage extends StatefulWidget {
  const PdfReaderPage({super.key});

  @override
  State<PdfReaderPage> createState() => _PdfReaderPageState();
}

class _PdfReaderPageState extends State<PdfReaderPage> {
  final store = LibraryStore();
  final searchController = TextEditingController();
  List<ReadingDocument> documents = const [];
  String query = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredDocuments = documents.where((document) {
      return document.title.toLowerCase().contains(query.toLowerCase());
    }).toList();

    return PageFrame(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'PDF study',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
              ),
              FilledButton.icon(
                onPressed: _importDocument,
                icon: const Icon(Icons.upload_file),
                label: const Text('Import'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: searchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Search documents',
            ),
            onChanged: (value) {
              setState(() => query = value);
            },
          ),
          const SizedBox(height: 16),
          if (filteredDocuments.isEmpty)
            const _EmptyDocumentState()
          else
            for (final document in filteredDocuments)
              _DocumentTile(
                document: document,
                noteCount: store.notesFor(document.id).length,
                onOpen: () => _openDocument(document),
                onDelete: () => _deleteDocument(document),
              ),
          const SizedBox(height: 12),
          const _PassageCard(),
        ],
      ),
    );
  }

  void _reload() {
    setState(() => documents = store.documents());
  }

  Future<void> _importDocument() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'epub'],
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.first;
    final bytes = await _readPickedFile(file);
    if (bytes == null) {
      return;
    }

    final document = ReadingDocument.fromPickedFile(
      fileName: file.name,
      bytes: bytes,
      filePath: file.path,
    );

    if (!mounted) {
      return;
    }

    final updatedDocuments = store.addDocument(document);
    final storedDocument = updatedDocuments.firstWhere(
      (stored) =>
          (document.filePath != null && stored.filePath == document.filePath) ||
          (document.filePath == null &&
              stored.title == document.title &&
              stored.type == document.type),
      orElse: () => document,
    );

    setState(() => documents = updatedDocuments);

    if (!storedDocument.canOpenInApp) {
      final message = storedDocument.type == ReadingDocumentType.epub
          ? 'EPUB imported and tracked. Add an EPUB renderer package to preview contents in-app.'
          : 'PDF imported, but no bytes were provided by the picker so it cannot be opened in-app.';
      _showMessage(message);
      return;
    }

    await _openDocument(storedDocument);
  }

  Future<Uint8List?> _readPickedFile(PlatformFile file) async {
    try {
      return file.readAsBytes();
    } catch (_) {
      if (mounted) {
        _showMessage('Could not read the selected file');
      }
      return null;
    }
  }

  Future<void> _openDocument(ReadingDocument document) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentReaderPage(document: document),
      ),
    );

    if (mounted) {
      _reload();
    }
  }

  void _deleteDocument(ReadingDocument document) {
    setState(() => documents = store.deleteDocument(document.id));
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({
    required this.document,
    required this.noteCount,
    required this.onOpen,
    required this.onDelete,
  });

  final ReadingDocument document;
  final int noteCount;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          document.type == ReadingDocumentType.epub
              ? Icons.menu_book_outlined
              : Icons.picture_as_pdf_outlined,
          color: colorScheme.primary,
        ),
        title: Text(document.title),
        subtitle: Text(_subtitle),
        onTap: onOpen,
        trailing: IconButton(
          tooltip: 'Delete document',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
        ),
      ),
    );
  }

  String get _subtitle {
    if (!document.canOpenInApp) {
      return '${document.type.label} - tracked only';
    }

    final notes = noteCount == 1 ? '1 note' : '$noteCount notes';
    return '${document.type.label} - page ${document.lastPageNumber} - $notes';
  }
}

class _EmptyDocumentState extends StatelessWidget {
  const _EmptyDocumentState();

  @override
  Widget build(BuildContext context) {
    return const Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text('Import a PDF or EPUB to build your reading library.'),
      ),
    );
  }
}

class _PassageCard extends StatelessWidget {
  const _PassageCard();

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
                Icon(Icons.sticky_note_2_outlined, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Selected passage workflow',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Search a document, capture an important passage, then turn it into a quiz card for review.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            const Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('Recall')),
                Chip(label: Text('Study plan')),
                Chip(label: Text('Quiz source')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
