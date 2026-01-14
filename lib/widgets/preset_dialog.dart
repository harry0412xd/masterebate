// lib/widgets/preset_dialog.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/card_model.dart';
import '../providers/card_provider.dart';

class PresetDialog extends StatefulWidget {
  final CardModel card;
  const PresetDialog({super.key, required this.card});

  @override
  State<PresetDialog> createState() => _PresetDialogState();
}

class _PresetDialogState extends State<PresetDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('All Presets'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: ListView.builder(
          itemCount: widget.card.presets.length,
          itemBuilder: (context, i) {
            final p = widget.card.presets[i];
            return ListTile(
              title: Text('${p.description} – \$${p.amount.toStringAsFixed(2)}'),
              subtitle: Text('Used ${p.frequency} time${p.frequency == 1 ? '' : 's'}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.edit), onPressed: () => _edit(p)),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () {
                      Provider.of<CardProvider>(context, listen: false).deletePreset(p);
                      setState(() {});
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }

  void _edit(Preset p) {
    final descCtrl = TextEditingController(text: p.description);
    final amountCtrl = TextEditingController(text: p.amount.toString());

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Preset'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description')),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final newAmount = double.tryParse(amountCtrl.text);
              if (newAmount != null) {
                Provider.of<CardProvider>(context, listen: false)
                    .editPreset(p, descCtrl.text, newAmount);
                Navigator.pop(context);
                setState(() {});
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}