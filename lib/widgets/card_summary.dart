// lib/widgets/card_summary.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final periodStart = provider.getPeriodStart(provider.currentDate, card.monthlyCutoff);
    final currentExpense = provider.getCurrentExpense(card);
    final requiredSpend = card.getRequiredSpend();
    final remaining = requiredSpend - currentExpense;
    final rebateUsed = provider.getRebateUsed(card);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          if (card.imagePath != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                File(card.imagePath!),
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          if (card.imagePath != null) const SizedBox(height: 16),
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
                  '${DateFormat('d MMM yyyy').format(periodStart)} – ${DateFormat('d MMM yyyy').format(provider.currentDate)}',
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
                    const Text('Required for rebate:'),
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
                    const Text('Remaining:'),
                    Text(
                      remaining >= 0
                          ? '\$${remaining.toStringAsFixed(2)}'
                          : 'Achieved',
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
                    const Text('Rebate used:'),
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