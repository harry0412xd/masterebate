// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/card_provider.dart';
import 'manage_cards_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CardProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.file_download),
            title: const Text('Import from CSV'),
            onTap: () => provider.importFromCsv(),
          ),
          ListTile(
            leading: const Icon(Icons.file_upload),
            title: const Text('Export to CSV'),
            onTap: () => provider.exportToCsv(context),
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
                MaterialPageRoute(builder: (_) => const ManageCardsScreen()),
              );
            },
          ),
          const Divider(),
        ],
      ),
    );
  }
}