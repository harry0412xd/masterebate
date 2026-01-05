// lib/widgets/custom_entry_dialog.dart
import 'package:flutter/material.dart';

class CustomEntryDialog extends StatefulWidget {
  final Function(double, String, bool) onAdd;

  const CustomEntryDialog({super.key, required this.onAdd});

  @override
  State<CustomEntryDialog> createState() => _CustomEntryDialogState();
}

class _CustomEntryDialogState extends State<CustomEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _saveAsPreset = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Expense'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount (\$)'),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (double.tryParse(v) == null) return 'Invalid number';
                return null;
              },
            ),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Description (optional)'),
            ),
            CheckboxListTile(
              title: const Text('Save as Preset'),
              value: _saveAsPreset,
              onChanged: (v) => setState(() => _saveAsPreset = v!),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final amount = double.parse(_amountCtrl.text);
              final desc = _descCtrl.text.isEmpty ? 'Custom' : _descCtrl.text;
              widget.onAdd(amount, desc, _saveAsPreset);
              Navigator.pop(context);
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}