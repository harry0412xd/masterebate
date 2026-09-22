// lib/widgets/card_summary.dart
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/card_provider.dart';
import '../models/card_model.dart';
import '../utils/image_utils.dart';

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
    if (image == null) return;

    // Copy to permanent storage
    final permanentPath = await saveCardImagePermanently(image.path);

    final updated = CardModel(
      name: card.name,
      monthlyCutoff: card.monthlyCutoff,
      rebateCutoff: card.rebateCutoff,
      extraRebatePct: card.extraRebatePct,
      quota: card.quota,
      imagePath: permanentPath ?? image.path,
      isHidden: card.isHidden,
      expenses: card.expenses,
      presets: card.presets,
    );
    provider.editCard(updated);
  }

  void _deleteCard(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Card'),
        content: const Text(
            'Are you sure you want to delete this card and all its data?'),
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

    // Statement period (monthlyCutoff)
    final statementStart = provider.getPeriodStart(today, card.monthlyCutoff);
    final nextStatementStart = provider.getPeriodStart(
      today.add(const Duration(days: 40)),
      card.monthlyCutoff,
    );
    final statementEnd = nextStatementStart.subtract(const Duration(days: 1));

    // Rebate period (rebateCutoff)
    final rebateStart = provider.getPeriodStart(today, card.rebateCutoff);
    final nextRebateStart = provider.getPeriodStart(
      today.add(const Duration(days: 40)),
      card.rebateCutoff,
    );
    final rebateEnd = nextRebateStart.subtract(const Duration(days: 1));

    final currentExpense = provider.getCurrentExpense(card);
    final rebatePeriodExpense = provider.getRebatePeriodExpense(card);
    final requiredSpend = card.getRequiredSpend();
    final remaining = requiredSpend - rebatePeriodExpense;
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
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.outline),
                borderRadius: BorderRadius.circular(16),
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: card.imagePath != null
                    ? Center(
                        child: AspectRatio(
                          aspectRatio: 1002 / 629,
                          child: SafeCardImage(
                            imagePath: card.imagePath,
                            fit: BoxFit.contain,
                          ),
                        ),
                      )
                    : Center(
                        child: Icon(
                          Icons.credit_card,
                          size: 80,
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.5),
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
                  '${DateFormat('d MMM yyyy').format(statementStart)} – ${DateFormat('d MMM yyyy').format(statementEnd)}',
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Spend this statement:'),
                    Text(
                      '\$${currentExpense.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Text(
                  'Rebate Period',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '${DateFormat('d MMM yyyy').format(rebateStart)} – ${DateFormat('d MMM yyyy').format(rebateEnd)}',
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Spend this rebate period:'),
                    Text(
                      '\$${rebatePeriodExpense.toStringAsFixed(2)}',
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
