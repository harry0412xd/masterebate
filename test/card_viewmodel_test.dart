import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:masterebate/viewmodels/card_viewmodel.dart';
import 'package:masterebate/services/card_repository.dart';
import 'package:masterebate/models/card_model.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('Import -> add card -> delete current -> delete non-current -> presets/expenses -> export CSV', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = CardRepository(prefs);
    final vm = CardViewModel(repo);

    // 1) import via CSV string
    final csv = '''Card,Monthly Cutoff,Rebate Cutoff,Extra Rebate %,Quota
Test Card,15,31,5,100

Card,Date,Amount,Description
Test Card,2024-01-01,50,Initial
''';
    final importMsg = vm.importFromCsvString(csv);
    expect(importMsg, 'Imported 1');
    expect(vm.cards.length, 1);
    expect(vm.cards.first.name, 'Test Card');

    // 2) add a new card
    vm.addCard(CardModel(name: 'New Card', monthlyCutoff: 1, rebateCutoff: 31, extraRebatePct: 2.0, quota: 10.0));
    expect(vm.cards.length, 2);
    expect(vm.currentIndex, 1);

    // 3) delete current card
    vm.deleteCard();
    expect(vm.cards.length, 1);
    expect(vm.currentIndex, 0);

    // 4) remove non-current card: add a second card again
    vm.addCard(CardModel(name: 'Other Card', monthlyCutoff: 1, rebateCutoff: 31, extraRebatePct: 1.0, quota: 5.0));
    expect(vm.cards.length, 2);

    // delete non-current (index 1) using deleteCardAt
    vm.deleteCardAt(1);
    expect(vm.cards.length, 1);

    // 5) add expenses with preset creation
    vm.addExpense(20.0, 'Lunch', saveAsPreset: true);
    final card = vm.currentCard!;
    expect(card.expenses.any((e) => e.amount == 20.0 && e.description == 'Lunch'), isTrue);
    expect(card.presets.any((p) => p.description == 'Lunch' && p.amount == 20.0), isTrue);

    // 6) add expense with the created preset
    final preset = card.presets.firstWhere((p) => p.description == 'Lunch');
    vm.addFromPreset(preset);
    expect(card.expenses.where((e) => e.description == 'Lunch').length, 2);
    expect(preset.frequency, greaterThanOrEqualTo(2));

    // 7) export CSV string and verify contains expected entries
    final outCsv = await vm.exportCsvString();
    expect(outCsv.contains('Test Card'), isTrue);
    expect(outCsv.contains('Lunch'), isTrue);

    // Also test exportToCsv fallback (writes to temp when FilePicker unimplemented)
    final exportResult = await vm.exportToCsv();
    expect(exportResult, isNotNull);
    expect(exportResult, isNot('cancelled'));

    // If a filepath returned, the file should contain our CSV
    if (exportResult != null && exportResult != 'cancelled' && exportResult != 'no_cards' && (exportResult.contains('/') || exportResult.contains('\\'))) {
      final file = File(exportResult);
      final contents = await file.readAsString();
      expect(contents.contains('Lunch'), isTrue);
    }
  });
}