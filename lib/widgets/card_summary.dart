// lib/widgets/card_summary.dart
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/card_provider.dart';
import '../models/card_model.dart';

class CardSummary extends StatelessWidget {
  final CardModel card;
  final CardProvider provider;

  const CardSummary({
    super.key,
    required this.card,
    required this.provider,
  });

  Future<void> _pickImage(BuildContext context) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final updated = CardModel(
        name: card.name,
        monthlyCutoff: card.monthlyCutoff,
        rebateCutoff: card.rebateCutoff,
        extraRebatePct: card.extraRebatePct,
        quota: card.quota,
        imagePath: image.path,
        expenses: card.expenses,    // Preserve existing expenses
        presets: card.presets,      // Preserve existing presets
      );
      provider.editCard(updated);
    }
  }

  void _deleteCard(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Card'),
        content: const Text('Are you sure you want to delete this card and all its data?'),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = provider.currentDate;
    final periodStart = provider.getPeriodStart(today, card.monthlyCutoff);
    final nextPeriodStart = provider.getPeriodStart(
      today.add(const Duration(days: 40)),
      card.monthlyCutoff,
    );
    final periodEnd = nextPeriodStart.subtract(const Duration(days: 1));

    final currentExpense = provider.getCurrentExpense(card);
    final requiredSpend = card.getRequiredSpend();
    final remaining = requiredSpend - currentExpense;
    final rebateUsed = provider.getRebateUsed(card);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _pickImage(context),
            onLongPress: () {
              if (!kIsWeb &&
                  defaultTargetPlatform != TargetPlatform.windows &&
                  defaultTargetPlatform != TargetPlatform.macOS &&
                  defaultTargetPlatform != TargetPlatform.linux) {
                _deleteCard(context);
              }
            },
            child: Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.outline),
                borderRadius: BorderRadius.circular(16),
              ),
              child: card.imagePath != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        File(card.imagePath!),
                        fit: BoxFit.cover,
                      ),
                    )
                  : Center(
                      child: Icon(
                        Icons.credit_card,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            card.name,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Statement Period',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '${DateFormat('d MMM yyyy').format(periodStart)} – ${DateFormat('d MMM yyyy').format(periodEnd)}',
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Spend this period:'),
                    Text(
                      '\$${currentExpense.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Required for full rebate:'),
                    Text(
                      '\$${requiredSpend.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Remaining to spend:'),
                    Text(
                      remaining >= 0
                          ? '\$${remaining.toStringAsFixed(2)}'
                          : 'Target achieved',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: remaining >= 0 ? null : Colors.green,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Rebate earned this period:'),
                    Text(
                      '\$${rebateUsed.toStringAsFixed(2)} / \$${card.quota.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}