import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/storage/reading_storage.dart';
import '../../../core/widgets/page_frame.dart';
import '../../extensions/data/extension_store.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final repositoryController = TextEditingController();

  @override
  void dispose() {
    repositoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ValueListenableBuilder<Box<dynamic>>(
        valueListenable: ReadingStorage.box.listenable(),
        builder: (context, box, _) {
          final store = ExtensionStore(box: box);
          final repositories = store.repositories();

          return PageFrame(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Extensions',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: repositoryController,
                          decoration: const InputDecoration(
                            labelText: 'Repository URL',
                            hintText: 'Paste repository URL',
                            prefixIcon: Icon(Icons.link),
                          ),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _addRepository(store),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: () => _addRepository(store),
                              icon: const Icon(Icons.add),
                              label: const Text('Add repository'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (repositories.isEmpty)
                  const Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No extension repositories saved.'),
                    ),
                  )
                else
                  for (final repository in repositories)
                    Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const Icon(Icons.storage_outlined),
                        title: Text(repository.url),
                        trailing: IconButton(
                          tooltip: 'Delete repository',
                          onPressed: () {
                            store.deleteRepository(repository.url);
                          },
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _addRepository(ExtensionStore store) {
    final url = repositoryController.text.trim();
    if (url.isEmpty) {
      return;
    }

    final before = store.repositories().length;
    final repositories = store.addRepository(url);
    final added = repositories.length > before;
    repositoryController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added ? 'Repository added' : 'Repository already saved or invalid',
        ),
      ),
    );
  }
}
