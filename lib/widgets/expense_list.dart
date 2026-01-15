// lib/widgets/expense_list.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/card_model.dart';
import '../providers/card_provider.dart';

class ExpenseList extends StatefulWidget {
  final CardModel card;

  const ExpenseList({
    super.key,
    required this.card,
  });

  @override
  State<ExpenseList> createState() => _ExpenseListState();
}

class _ExpenseListState extends State<ExpenseList> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CardProvider>(context);
    final expenses = widget.card.expenses;

    if (expenses.isEmpty) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'No expenses recorded yet',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ),
      );
    }

    // Sort newest first
    final sortedExpenses = List<Expense>.from(expenses)
      ..sort((a, b) => b.date.compareTo(a.date));

    final visibleExpenses = _expanded ? sortedExpenses : sortedExpenses.take(5).toList();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: Text(
              'Expenses (${expenses.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            trailing: Icon(
              _expanded ? Icons.expand_less : Icons.expand_more,
            ),
            onTap: () {
              setState(() => _expanded = !_expanded);
            },
          ),
          const Divider(height: 1),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: visibleExpenses.length,
            itemBuilder: (context, index) {
              final expense = visibleExpenses[index];
              final isInCurrentPeriod = !expense.date.isBefore(
                provider.getPeriodStart(provider.currentDate, widget.card.monthlyCutoff),
              );

              return ListTile(
                dense: true,
                leading: isInCurrentPeriod
                    ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                    : const Icon(Icons.history, color: Colors.grey, size: 20),
                title: Text(
                  expense.description.isEmpty ? 'Custom entry' : expense.description,
                  style: const TextStyle(fontSize: 15),
                ),
                subtitle: Text(
                  DateFormat('d MMM yyyy • HH:mm').format(expense.date),
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Text(
                  'HKD ${expense.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              );
            },
          ),
          if (!_expanded && expenses.length > 5)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Text(
                'Tap to view all ${expenses.length} entries',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
        ],
      ),
    );
  }
}