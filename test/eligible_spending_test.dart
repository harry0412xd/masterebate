import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:masterebate/viewmodels/card_viewmodel.dart';
import 'package:masterebate/services/card_repository.dart';
import 'package:masterebate/models/card_model.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('Eligible spending excludes 0% expenses and computes remaining correctly', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = CardRepository(prefs);
    final vm = CardViewModel(repo);

    // Card: extraRebatePct 5.0%, quota 10 -> requiredSpend = 10 / 0.05 = 200
    vm.addCard(CardModel(name: 'Card B', monthlyCutoff: 1, rebateCutoff: 31, extraRebatePct: 5.0, quota: 10.0));

    final card = vm.cards.first;

    // Add an eligible expense at 5% -> counts fully
    vm.addExpense(100.0, 'Eligible', rebatePct: 5.0);

    // Add a 0% expense -> should NOT reduce eligible spending
    vm.addExpense(50.0, 'Not eligible', rebatePct: 0.0);

    final eligible = vm.getEligibleSpending(card);
    // 100 at 5% with card 5% => eligible spending = 100
    expect(eligible, closeTo(100.0, 0.001));

    final required = card.getRequiredSpend();
    expect(required, closeTo(200.0, 0.001));

    final remaining = required - eligible;
    expect(remaining, closeTo(100.0, 0.001));
  });
}
