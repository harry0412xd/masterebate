// lib/widgets/card_form.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/card_model.dart';

class CardForm extends StatefulWidget {
  final CardModel? card;
  final Function(CardModel) onSave;

  const CardForm({super.key, this.card, required this.onSave});

  @override
  State<CardForm> createState() => _CardFormState();
}

class _CardFormState extends State<CardForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _monthlyCtrl;
  late TextEditingController _rebateCtrl;
  late TextEditingController _pctCtrl;
  late TextEditingController _quotaCtrl;
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.card?.name ?? '');
    _monthlyCtrl = TextEditingController(text: widget.card?.monthlyCutoff.toString() ?? '');
    _rebateCtrl = TextEditingController(
      text: widget.card?.rebateCutoff.toString() ?? '31',
    );
    _pctCtrl = TextEditingController(text: widget.card?.extraRebatePct.toString() ?? '');
    _quotaCtrl = TextEditingController(text: widget.card?.quota.toString() ?? '');
    _imagePath = widget.card?.imagePath;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _monthlyCtrl.dispose();
    _rebateCtrl.dispose();
    _pctCtrl.dispose();
    _quotaCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _imagePath = image.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.card == null ? 'Add Card' : 'Edit Card'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Card Name'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _monthlyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Monthly Cutoff Day (1-31)'),
                validator: _validateDay,
              ),
              TextFormField(
                controller: _rebateCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Rebate Cutoff Day (1-31)'),
                validator: _validateDay,
              ),
              TextFormField(
                controller: _pctCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Extra Rebate %'),
                validator: _validateDouble,
              ),
              TextFormField(
                controller: _quotaCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Rebate Quota (\$)'),
                validator: _validateDouble,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.image),
                label: const Text('Pick Card Image'),
              ),
              if (_imagePath != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(File(_imagePath!), height: 120, fit: BoxFit.cover),
                  ),
                ),
            ],
          ),
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
              final newCard = CardModel(
                name: _nameCtrl.text.trim(),
                monthlyCutoff: int.parse(_monthlyCtrl.text),
                rebateCutoff: int.parse(_rebateCtrl.text),
                extraRebatePct: double.parse(_pctCtrl.text),
                quota: double.parse(_quotaCtrl.text),
                imagePath: _imagePath,
              );
              widget.onSave(newCard);
              Navigator.pop(context);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  String? _validateDay(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    final day = int.tryParse(value);
    if (day == null || day < 1 || day > 31) return 'Must be 1-31';
    return null;
  }

  String? _validateDouble(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    if (double.tryParse(value) == null) return 'Invalid number';
    return null;
  }
}