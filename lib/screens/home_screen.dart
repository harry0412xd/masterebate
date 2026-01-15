// lib/screens/home_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/card_provider.dart';
import '../models/card_model.dart';
import '../widgets/card_form.dart';
import '../widgets/preset_dialog.dart';
import '../widgets/custom_entry_dialog.dart';
import '../widgets/card_summary.dart';     // new
import '../widgets/expense_list.dart';      // new
import '../screens/overview_screen.dart';   // new
import '../widgets/quick_add_sheet.dart';  // new

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('MasterRebate'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Card'),
              Tab(text: 'Overview'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.calendar_today),
              tooltip: 'Debug Date',
              onPressed: () async {
                final provider = Provider.of<CardProvider>(context, listen: false);
                DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: provider.currentDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                );
                if (picked != null) {
                  provider.setDebugDate(picked);
                }
              },
            ),
            PopupMenuButton<String>(
              onSelected: (value) async {
                final provider = Provider.of<CardProvider>(context, listen: false);
                if (value == 'add') {
                  showDialog(
                    context: context,
                    builder: (_) => CardForm(onSave: provider.addCard),
                  );
                } else if (value == 'edit') {
                  final card = provider.currentCard;
                  if (card != null) {
                    showDialog(
                      context: context,
                      builder: (_) => CardForm(card: card, onSave: provider.editCard),
                    );
                  }
                } else if (value == 'delete') {
                  provider.deleteCard();
                } else if (value == 'export_csv') {
                  // await provider.exportToCsv(context);
                } else if (value == 'import_csv') {
                  // await provider.importFromCsv();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'add', child: Text('Add Card')),
                const PopupMenuItem(value: 'edit', child: Text('Edit Card')),
                const PopupMenuItem(value: 'delete', child: Text('Delete Card')),
                const PopupMenuItem(value: 'export_csv', child: Text('Export CSV')),
                const PopupMenuItem(value: 'import_csv', child: Text('Import CSV')),
              ],
            ),
          ],
        ),
        body: TabBarView(
          children: [
            const _CardTab(),
            const OverviewScreen(),
          ],
        ),
        bottomSheet: const _BottomQuickAddBar(),
      ),
    );
  }
}

class _CardTab extends StatefulWidget {
  const _CardTab();

  @override
  State<_CardTab> createState() => _CardTabState();
}

class _CardTabState extends State<_CardTab> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final provider = Provider.of<CardProvider>(context, listen: false);
    if (provider.quickAddRequested) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showQuickAddBottomSheet(context);   // ← your quick add function
        provider.consumeQuickAdd();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CardProvider>(
      builder: (context, provider, child) {
        final card = provider.currentCard;

        if (card == null) {
          return const Center(child: Text('No cards added yet\nTap menu → Add Card'));
        }

        return GestureDetector(
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity! > 300) provider.switchCard(-1);
            if (details.primaryVelocity! < -300) provider.switchCard(1);
          },
          child: ListView(
            children: [
              CardSummary(card: card, provider: provider),
              const SizedBox(height: 16),
              ExpenseList(card: card),
              const SizedBox(height: 140),
            ],
          ),
        );
      },
    );
  }
}
class _BottomQuickAddBar extends StatelessWidget {
  const _BottomQuickAddBar();

  @override
  Widget build(BuildContext context) {
    return Consumer<CardProvider>(
      builder: (context, provider, child) {
        final card = provider.currentCard;
        if (card == null) return const SizedBox.shrink();

        // Auto-show quick add when triggered by shortcut / tile
        if (provider.quickAddRequested) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // showQuickAddBottomSheet(context);   // ← implement this function
            provider.consumeQuickAdd();
          });
        }

        var sortedPresets = List<Preset>.from(card.presets)
          ..sort((a, b) => b.frequency.compareTo(a.frequency));
        var topPresets = sortedPresets.take(5).toList();

        return BottomAppBar(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => CustomEntryDialog(
                          onAdd: (amount, desc, saveAsPreset) {
                            provider.addExpense(amount, desc, saveAsPreset: saveAsPreset);
                          },
                        ),
                      );
                    },
                    child: const Text('Custom'),
                  ),
                  const SizedBox(width: 12),
                  ...topPresets.map((p) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ElevatedButton(
                          onPressed: () => provider.addFromPreset(p),
                          child: Text(
                            '${p.description}\n\$${p.amount.toStringAsFixed(2)}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )),
                  if (sortedPresets.length > 5)
                    ElevatedButton(
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => PresetDialog(card: card),
                      ),
                      child: const Text('⋯ More'),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
