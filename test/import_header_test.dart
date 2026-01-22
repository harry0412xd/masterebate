import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:masterebate/viewmodels/card_viewmodel.dart';
import 'package:masterebate/services/card_repository.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('Importing seed CSV does not create a header-named card', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = CardRepository(prefs);
    final vm = CardViewModel(repo);

    final seed = '''Card,Monthly Cutoff,Rebate Cutoff,Extra Rebate %,Quota
Debug Card,15,31,5,100

Preset,Card,Description,Amount,Extra Rebate %,Frequency
Debug Card,Snack,10,5,1

Card,Date,Amount,Description,Extra Rebate %
Debug Card,2024-01-01,50,Initial,5
''';

    final msg = vm.importFromCsvString(seed);
    expect(msg, isNotNull);
    expect(vm.cards.length, 1);
    expect(vm.cards.first.name, 'Debug Card');
    // Ensure no header-like card names imported
    expect(vm.cards.any((c) => c.name.toLowerCase().contains('card name') || c.name.toLowerCase() == 'card'), isFalse);
  });
}
