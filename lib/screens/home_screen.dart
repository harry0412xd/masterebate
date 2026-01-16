// lib/screens/home_screen.dart
import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/card_provider.dart';
import '../models/card_model.dart';
import '../widgets/card_form.dart';
import '../widgets/preset_dialog.dart';
import '../widgets/custom_entry_dialog.dart';
import '../widgets/card_summary.dart';
import '../widgets/expense_list.dart';
import '../screens/overview_screen.dart';
import '../screens/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const SizedBox.shrink(), // No title
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Card'),
            Tab(text: 'Overview'),
          ],
        ),
        actions: [
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.calendar_today),
              tooltip: 'Set Debug Date',
              onPressed: () async {
                final provider = Provider.of<CardProvider>(context, listen: false);
                final picked = await showDatePicker(
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
            onSelected: (value) {
              final provider = Provider.of<CardProvider>(context, listen: false);
              if (value == 'add') {
                showDialog(
                  context: context,
                  builder: (_) => CardForm(onSave: provider.addCard),
                );
              } else if (value == 'delete') {
                final card = provider.currentCard;
                if (card == null) return;
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Remove Card'),
                    content: Text('Delete "${card.name}" and all its expenses?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        onPressed: () {
                          provider.deleteCard();
                          Navigator.pop(ctx);
                        },
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
                );
              } else if (value == 'settings') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'add', child: Text('Add Card')),
              const PopupMenuItem(value: 'delete', child: Text('Remove Card')),
              const PopupMenuItem(value: 'settings', child: Text('Settings')),
            ],
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _CardTab(),
          OverviewScreen(),
        ],
      ),
      bottomNavigationBar: _tabController.index == 0 ? const _BottomQuickAddBar() : null,
    );
  }
}

class _CardTab extends StatelessWidget {
  const _CardTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<CardProvider>(
      builder: (context, provider, _) {
        final cards = provider.cards;

        if (cards.isEmpty) {
          return const Center(
            child: Text(
              'No cards yet\nUse menu → Add Card',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
          );
        }

        return Column(
          children: [
            SizedBox(
              height: 68,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                itemCount: cards.length,
                itemBuilder: (context, index) {
                  final card = cards[index];
                  final isSelected = provider.currentIndex == index;
                  return GestureDetector(
                    onTap: () => provider.setCurrentIndex(index),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Container(
                        width: 64,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                            width: 2.5,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  )
                                ]
                              : null,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: card.imagePath != null
                            ? Image.file(File(card.imagePath!), fit: BoxFit.cover)
                            : Container(
                                color: Theme.of(context).colorScheme.surfaceContainer,
                                child: const Icon(Icons.credit_card, size: 32),
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Expanded(
              child: GestureDetector(
                onHorizontalDragEnd: (details) {
                  if (details.primaryVelocity! > 400) provider.switchCard(-1);
                  if (details.primaryVelocity! < -400) provider.switchCard(1);
                },
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 140),
                  children: [
                    CardSummary(
                      card: provider.currentCard!,
                      provider: provider,
                    ),
                    const SizedBox(height: 16),
                    ExpenseList(card: provider.currentCard!),
                  ],
                ),
              ),
            ),
          ],
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
      builder: (context, provider, _) {
        final card = provider.currentCard;
        if (card == null) return const SizedBox.shrink();

        var sorted = List<Preset>.from(card.presets)
          ..sort((a, b) => b.frequency.compareTo(a.frequency));
        var top = sorted.take(5).toList();

        return BottomAppBar(
          height: 80,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => CustomEntryDialog(
                          onAdd: (amt, desc, save) => provider.addExpense(amt, desc, saveAsPreset: save),
                        ),
                      );
                    },
                    child: const Text('Custom'),
                  ),
                  const SizedBox(width: 12),
                  ...top.map((p) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilledButton.tonal(
                          onPressed: () => provider.addFromPreset(p),
                          child: Text(
                            '${p.description}\n\$${p.amount.toStringAsFixed(0)}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      )),
                  if (sorted.length > 5)
                    FilledButton.tonal(
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => PresetDialog(card: card),
                      ),
                      child: const Text('More…'),
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