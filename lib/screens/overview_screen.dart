import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/card_provider.dart';
import '../widgets/quota_progress_bar.dart';

class OverviewScreen extends StatelessWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CardProvider>(context);
    final cards = provider.cards;

    if (cards.isEmpty) {
      return const Center(child: Text('No cards yet'));
    }

    double totalExpense = 0;
    double totalRebateUsed = 0;

    for (var card in cards) {
      totalExpense += provider.getCurrentExpense(card);
      totalRebateUsed += provider.getRebateUsed(card);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Expenses (current periods)', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('HKD ${totalExpense.toStringAsFixed(2)}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Text('Total Rebate Used: HKD ${totalRebateUsed.toStringAsFixed(2)}'),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),
        Text('Quota Usage', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),

        ...cards.map((card) {
          final used = provider.getRebateUsed(card);
          final quota = card.quota;
          final percent = quota > 0 ? (used / quota).clamp(0.0, 2.0) : 0.0;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(card.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                QuotaProgressBar(
                  value: percent,
                  label: '${(percent * 100).toStringAsFixed(0)}% – ${used.toStringAsFixed(2)} / ${quota.toStringAsFixed(2)}',
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}