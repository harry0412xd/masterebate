import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:masterebate/viewmodels/card_viewmodel.dart';
import 'package:masterebate/services/card_repository.dart';
import 'package:masterebate/models/card_model.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('Raw base64 image in CSV is wrapped into a data URL on import', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = CardRepository(prefs);
    final vm = CardViewModel(repo);

    final b64 = base64Encode([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]);
    final csv = '''Card Name,Monthly Cutoff,Rebate Cutoff,Extra Rebate %,Quota,Image
PhotoCard,1,31,5,100,$b64
''';

    final msg = vm.importFromCsvString(csv);
    expect(msg, isNotNull);
    expect(vm.cards.length, 1);
    final imported = vm.cards.first;
    expect(imported.name, 'PhotoCard');
    expect(imported.imagePath, startsWith('data:image/png;base64,'));
    expect(imported.imagePath!.contains(b64), isTrue);
  });

  test('Header row with "Card Name" is not imported as a card', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = CardRepository(prefs);
    final vm = CardViewModel(repo);

    final csv = 'Card Name,Monthly Cutoff,Rebate Cutoff,Extra Rebate %,Quota,Image\n';

    final msg = vm.importFromCsvString(csv);
    expect(msg, isNull);
    expect(vm.cards.length, 0);
  });
}
