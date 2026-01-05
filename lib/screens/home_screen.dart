// lib/screens/home_screen.dart (Google Sheets options removed)
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/card_provider.dart';
import '../models/card_model.dart';
import '../widgets/card_form.dart';
import '../widgets/preset_dialog.dart';
import '../widgets/custom_entry_dialog.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CardProvider>(
      builder: (context, provider, child) {
        CardModel? card = provider.currentCard;
        return GestureDetector(
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity! > 0) {
              provider.switchCard(-1);
            } else if (details.primaryVelocity! < 0) {
              provider.switchCard(1);
            }
          },
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Credit Card Tracker'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.calendar_today),
                  tooltip: 'Debug Date: ${DateFormat('yyyy-MM-dd').format(provider.currentDate)}',
                  onPressed: () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: provider.currentDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) provider.setDebugDate(picked);
                  },
                ),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'add') {
                      showDialog(
                        context: context,
                        builder: (_) => CardForm(onSave: provider.addCard),
                      );
                    } else if (value == 'edit' && card != null) {
                      showDialog(
                        context: context,
                        builder: (_) => CardForm(card: card, onSave: provider.editCard),
                      );
                    } else if (value == 'delete') {
                      provider.deleteCard();
                    } else if (value == 'export_csv') {
                      await provider.exportToCsv(context);
                    } else if (value == 'import_csv') {
                      await provider.importFromCsv();
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'add', child: Text('Add Card')),
                    const PopupMenuItem(value: 'edit', child: Text('Edit Card')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete Card')),
                    const PopupMenuItem(value: 'export_csv', child: Text('Export Full Backup (CSV)')),
                    const PopupMenuItem(value: 'import_csv', child: Text('Import Full Backup (CSV)')),
                  ],
                ),
              ],
            ),
            // ... rest of body unchanged (image, expense display, bottom buttons)
            body: card == null
                ? const Center(child: Text('No cards yet – add one!'))
                : Column(
                    children: [
                      if (card.imagePath != null)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(
                              File(card.imagePath!),
                              height: 220,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),
                      Text(
                        card.name,
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            Text(
                              'Expense: \$${provider.getCurrentExpense(card).toStringAsFixed(2)} / '
                              '\$${card.getRequiredSpend().toStringAsFixed(2)} '
                              '(\$${(card.getRequiredSpend() - provider.getCurrentExpense(card)).toStringAsFixed(2)} left)',
                              style: const TextStyle(fontSize: 18),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Rebate Used: \$${provider.getRebateUsed(card).toStringAsFixed(2)} / \$${card.quota.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 18),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      BottomAppBar(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => CustomEntryDialog(
                                      onAdd: (amount, desc, save) =>
                                          provider.addExpense(amount, desc, saveAsPreset: save),
                                    ),
                                  );
                                },
                                child: const Text('Custom'),
                              ),
                              ..._buildPresetButtons(context, provider, card),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  List<Widget> _buildPresetButtons(BuildContext context, CardProvider provider, CardModel card) {
    var sorted = List<Preset>.from(card.presets)
      ..sort((a, b) => b.frequency.compareTo(a.frequency));
    var top5 = sorted.take(5).toList();

    List<Widget> buttons = top5
        .map((p) => ElevatedButton(
              onPressed: () => provider.addFromPreset(p),
              child: Text('${p.description}\n\$${p.amount.toStringAsFixed(2)}'),
            ))
        .toList();

    if (sorted.length > 5) {
      buttons.add(ElevatedButton(
        onPressed: () => showDialog(
          context: context,
          builder: (_) => PresetDialog(card: card),
        ),
        child: const Text('...'),
      ));
    }
    return buttons;
  }
}