// lib/widgets/card_summary.dart
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../providers/card_provider.dart';
import '../models/card_model.dart';
import 'package:provider/provider.dart';
import '../widgets/card_form.dart';
import 'image_display.dart';

class CardSummary extends StatelessWidget {
  final CardModel card;
  final CardProvider provider;

  const CardSummary({
    super.key,
    required this.card,
    required this.provider,
  });


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

    final eligibleSpending = provider.getEligibleSpending(card);
    final requiredSpend = card.getRequiredSpend();
    final remaining = requiredSpend - eligibleSpending;
    final rebateUsed = provider.getRebateUsed(card);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              // Open edit dialog for this card (prefill values and allow picking image)
              final provider = Provider.of<CardProvider>(context, listen: false);
              final index = provider.cards.indexOf(card);
              if (index != -1) provider.setCurrentIndex(index);

              showDialog(
                context: context,
                builder: (_) => CardForm(
                  card: card,
                  onSave: (updated) {
                    provider.editCard(updated);
                  },
                ),
              );
            },
            onLongPress: () {
              if (!kIsWeb &&
                  defaultTargetPlatform != TargetPlatform.windows &&
                  defaultTargetPlatform != TargetPlatform.macOS &&
                  defaultTargetPlatform != TargetPlatform.linux) {
                _deleteCard(context);
              }
            },
            child: Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.outline),
                borderRadius: BorderRadius.circular(16),
                color: Theme.of(context).colorScheme.surfaceContainerLowest, // subtle bg
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: card.imagePath != null
                    ? Center(                                 // ← center + contain
                        child: AspectRatio(
                          aspectRatio: 1002 / 629,
                          child: ImageDisplay(pathOrDataUrl: card.imagePath, fit: BoxFit.contain),
                        ),
                      )
                    : Center(
                      child: Icon(
                        Icons.credit_card,
                        size: 80,
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                      ),
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
                    const Text('Eligible Spending:'),
                    Text(
                      '\$${eligibleSpending.toStringAsFixed(2)}',
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