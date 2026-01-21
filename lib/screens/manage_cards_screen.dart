import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/card_provider.dart';
import '../models/card_model.dart';

class ManageCardsScreen extends StatelessWidget {
  const ManageCardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Cards')),
      body: Consumer<CardProvider>(
        builder: (context, provider, child) {
          final cards = provider.cards;

          if (cards.isEmpty) {
            return const Center(
              child: Text(
                'No cards added yet.\nAdd one from the home screen menu.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            itemCount: cards.length,
            itemBuilder: (context, index) {
              final card = cards[index];
              final isCurrent = index == provider.currentIndex;

              return ListTile(
                leading: isCurrent
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : const Icon(Icons.credit_card_outlined),
                title: Text(card.name),
                subtitle: isCurrent
                    ? const Text('Current card')
                    : Text('${card.expenses.length} expenses'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        card.isHidden ? Icons.visibility_off : Icons.visibility,
                        color: card.isHidden ? Colors.grey : Colors.blue,
                      ),
                      tooltip: card.isHidden ? 'Unhide card' : 'Hide card',
                      onPressed: () {
                        provider.toggleCardHidden(index);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      tooltip: 'Delete card',
                      onPressed: () =>
                          _confirmDelete(context, provider, index, card),
                    ),
                  ],
                ),
                onTap: () {
                  // Optional: switch to selected card
                  provider.setCurrentIndex(index);
                },
              );
            },
          );
        },
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    CardProvider provider,
    int index,
    CardModel card,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Card'),
        content: Text(
          'Delete "${card.name}" and all its expenses?\n'
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              // Temporarily switch to the card we want to delete
              final originalIndex = provider.currentIndex;
              provider.setCurrentIndex(index);
              provider.deleteCard();

              Navigator.pop(ctx);

              // If no cards left → go back to previous screen
              if (provider.cards.isEmpty) {
                Navigator.pop(context);
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
