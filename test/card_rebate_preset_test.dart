import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:masterebate/viewmodels/card_viewmodel.dart';
import 'package:masterebate/services/card_repository.dart';
import 'package:masterebate/models/card_model.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('Expense rebate per-entry and presets are stored/exported/imported', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = CardRepository(prefs);
    final vm = CardViewModel(repo);

    // Add a card with a default extra rebate percent
    vm.addCard(CardModel(name: 'Card A', monthlyCutoff: 1, rebateCutoff: 31, extraRebatePct: 5.0, quota: 100));

    // Add expense and save as preset (should inherit rebatePct=5.0)
    vm.addExpense(20.0, 'Lunch', saveAsPreset: true);
    final card = vm.cards.first;
    expect(card.presets.isNotEmpty, isTrue);
    final preset = card.presets.firstWhere((p) => p.description == 'Lunch');
    expect(preset.rebatePct, 5.0);

    // Add from preset -> expense should have rebatePct == 5.0
    vm.addFromPreset(preset);
    expect(card.expenses.where((e) => e.description == 'Lunch').length, 2);
    expect(card.expenses.any((e) => e.rebatePct == 5.0), isTrue);

    // Export CSV and check headers include Extra Rebate % and preset data present
    final csv = await vm.exportCsvString();
    expect(csv.contains('Extra Rebate %'), isTrue);
    expect(csv.contains('Lunch'), isTrue);

    // Import the CSV into a fresh ViewModel and verify presets & expense rebate persisted
    final prefs2 = await SharedPreferences.getInstance();
    final repo2 = CardRepository(prefs2);
    final vm2 = CardViewModel(repo2);

    final importMsg = vm2.importFromCsvString(csv);
    expect(importMsg, isNotNull);
    expect(vm2.cards.length, 1);
    final imported = vm2.cards.first;
    expect(imported.presets.any((p) => p.description == 'Lunch' && p.rebatePct == 5.0), isTrue);
    expect(imported.expenses.any((e) => e.description == 'Lunch' && e.rebatePct == 5.0), isTrue);
  });
}
