import 'package:flutter/material.dart';

class PdfReaderPage extends StatelessWidget {
  const PdfReaderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PDF Reader')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PDF Study Mode',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                const Text(
                  'The original app included PDF viewer utilities. In the portfolio version, this feature should support opening a PDF, searching text, and attaching quiz questions to selected passages.',
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: null,
                  icon: Icon(Icons.upload_file),
                  label: Text('Add PDF file'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
