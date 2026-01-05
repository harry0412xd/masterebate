// lib/screens/home_screen.dart (FULL FIXED FILE)
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
            body: card == null
                ? const Center(child: Text('No cards yet – add one!'))
                : ListView(
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
                      Center(
                        child: Text(
                          card.name,
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // === Statement Period Info ===
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current Statement Period:',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${DateFormat('MMM dd, yyyy').format(provider.getPeriodStart(provider.currentDate, card.monthlyCutoff))} – '
                              '${DateFormat('MMM dd, yyyy').format(provider.currentDate)}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 16),

                            Text(
                              'Expense in Period: \$${provider.getCurrentExpense(card).toStringAsFixed(2)} / '
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

                      const SizedBox(height: 24),

                      // === Collapsible Expense List ===
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _ExpenseList(card: card, provider: provider),
                      ),

                      const SizedBox(height: 100), // Space for bottom buttons
                    ],
                  ),
            bottomSheet: card == null
                ? null
                : BottomAppBar(
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
                          ..._buildPresetButtons(context, provider, card!), // Fixed: card!
                        ],
                      ),
                    ),
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

class _ExpenseList extends StatefulWidget {
  final CardModel card;
  final CardProvider provider;

  const _ExpenseList({required this.card, required this.provider});

  @override
  State<_ExpenseList> createState() => _ExpenseListState();
}

class _ExpenseListState extends State<_ExpenseList> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final expenses = widget.card.expenses;
    if (expenses.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: Text('No expenses yet')),
        ),
      );
    }

    // Sort newest first
    final sortedExpenses = expenses..sort((a, b) => b.date.compareTo(a.date));

    // Always show last 3
    final visible = _expanded ? sortedExpenses : sortedExpenses.take(3).toList();

    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text(
              'Recent Expenses (${expenses.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            trailing: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          const Divider(height: 1),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: visible.length,
            itemBuilder: (context, i) {
              final exp = visible[i];
              return ListTile(
                dense: true,
                title: Text(exp.description.isEmpty ? 'Custom' : exp.description),
                subtitle: Text(DateFormat('MMM dd, yyyy').format(exp.date)),
                trailing: Text('\$${exp.amount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              );
            },
          ),
          if (!_expanded && expenses.length > 3)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Tap to show all ${expenses.length} expenses',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}