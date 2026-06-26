import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../library/data/library_store.dart';
import '../../library/models/reading_document.dart';

class BookProgressPage extends StatefulWidget {
  const BookProgressPage({
    required this.document,
    super.key,
  });

  final ReadingDocument document;

  @override
  State<BookProgressPage> createState() => _BookProgressPageState();
}

class _BookProgressPageState extends State<BookProgressPage> {
  final store = LibraryStore();
  late ReadingDocument document;
  late TextEditingController currentPageController;
  late TextEditingController totalPagesController;

  @override
  void initState() {
    super.initState();
    document = widget.document;
    currentPageController = TextEditingController(
      text: document.lastPageNumber.toString(),
    );
    totalPagesController = TextEditingController(
      text: document.pageCount.toString(),
    );
  }

  @override
  void dispose() {
    currentPageController.dispose();
    totalPagesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(document.title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        document.type == ReadingDocumentType.book
                            ? Icons.menu_book_outlined
                            : Icons.insert_drive_file_outlined,
                        size: 40,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        document.title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      if (document.author != null) ...[
                        const SizedBox(height: 4),
                        Text(document.author!),
                      ],
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          minHeight: 10,
                          value: document.progress,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${document.progressPercent}% - ${document.progressLabel}',
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: currentPageController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Current page',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: totalPagesController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Total pages',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: _saveProgress,
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Save progress'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveProgress() {
    final totalPages = int.tryParse(totalPagesController.text.trim()) ?? 0;
    final currentPage = int.tryParse(currentPageController.text.trim()) ?? 0;
    final updatedDocument = store.updateManualBookProgress(
      document.id,
      currentPage: currentPage,
      totalPages: totalPages,
    );

    if (updatedDocument == null) {
      return;
    }

    setState(() {
      document = updatedDocument;
      currentPageController.text = document.lastPageNumber.toString();
      totalPagesController.text = document.pageCount.toString();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Progress saved')),
    );
  }
}
