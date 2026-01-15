import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/card_provider.dart';
import '../models/card_model.dart';

void showQuickAddBottomSheet(BuildContext context) {
  String? selectedCardName;
  Preset? selectedPreset;
  final amountCtrl = TextEditingController();

  final provider = Provider.of<CardProvider>(context, listen: false);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: StatefulBuilder(
        builder: (ctx, setModalState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Quick Add Expense", style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              value: selectedCardName,
              decoration: const InputDecoration(labelText: "Card"),
              items: provider.cards
                  .map((c) => DropdownMenuItem(value: c.name, child: Text(c.name)))
                  .toList(),
              onChanged: (v) {
                setModalState(() {
                  selectedCardName = v;
                  selectedPreset = null;
                });
              },
            ),
            const SizedBox(height: 16),
            if (selectedCardName != null) ...[
              DropdownButtonFormField<Preset>(
                value: selectedPreset,
                decoration: const InputDecoration(labelText: "Preset (optional)"),
                items: provider.cards
                    .firstWhere((c) => c.name == selectedCardName!)
                    .presets
                    .map((p) => DropdownMenuItem(
                          value: p,
                          child: Text("${p.description} – \$${p.amount.toStringAsFixed(2)}"),
                        ))
                    .toList(),
                onChanged: (v) => setModalState(() => selectedPreset = v),
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Amount",
                prefixText: "\$ ",
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                final amt = double.tryParse(amountCtrl.text);
                if (amt == null || selectedCardName == null) return;

                final card = provider.cards.firstWhere((c) => c.name == selectedCardName);
                final desc = selectedPreset?.description ?? "Quick entry";

                provider.addExpense(amt, desc, saveAsPreset: false);

                // Optional: switch to that card
                provider.setCurrentIndex(provider.cards.indexOf(card));

                Navigator.pop(context);
              },
              child: const Text("Add"),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  );
}