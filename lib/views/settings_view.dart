// lib/views/settings_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/card_viewmodel.dart';
import 'manage_cards_view.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CardViewModel>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.file_download),
            title: const Text('Import from CSV'),
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              final msg = await provider.importFromCsv();
              if (msg == null) return;
              if (msg == 'cancelled') {
                messenger.showSnackBar(const SnackBar(content: Text('Import cancelled')));
              } else {
                messenger.showSnackBar(SnackBar(content: Text(msg)));
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.file_upload),
            title: const Text('Export to CSV'),
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              final result = await provider.exportToCsv();
              if (result == 'no_cards') {
                messenger.showSnackBar(const SnackBar(content: Text('No cards to export')));
              } else if (result == 'cancelled') {
                messenger.showSnackBar(const SnackBar(content: Text('Export cancelled')));
              } else if (result != null) {
                messenger.showSnackBar(SnackBar(content: Text('Saved to $result')));
              }
            }, 
          ),
          const Divider(),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode),
            title: const Text('Dark Mode'),
            subtitle: const Text('Follow system setting'),
            value: Theme.of(context).brightness == Brightness.dark,
            onChanged: (_) {
              // For real toggle you would need a ThemeMode provider.
              // For now just show info
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Use system dark mode setting')),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.manage_accounts),
            title: const Text('Manage Cards'),
            subtitle: const Text('Delete or view cards'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManageCardsView()),
              );
            },
          ),
          const Divider(),
        ],
      ),
    );
  }
}
