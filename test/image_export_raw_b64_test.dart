import 'dart:convert';
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

  test('Export strips data URL prefix and writes raw base64', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = CardRepository(prefs);
    final vm = CardViewModel(repo);

    final b64 = base64Encode([10, 20, 30, 40, 50]);
    final dataUrl = 'data:image/png;base64,$b64';

    vm.addCard(CardModel(name: 'DataUrlCard', monthlyCutoff: 1, rebateCutoff: 31, extraRebatePct: 5.0, quota: 100, imagePath: dataUrl));

    final csv = await vm.exportCsvString();
    // Should contain raw base64 and not the data URL prefix
    expect(csv.contains(b64), isTrue);
    expect(csv.contains('data:image/png;base64,'), isFalse);
  });

  test('Export reads local file and writes raw base64', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = CardRepository(prefs);
    final vm = CardViewModel(repo);

    // Create a temp file with known bytes
    final tmp = Directory.systemTemp.createTempSync('mb-test-');
    final file = File('${tmp.path}/img.bin');
    final bytes = <int>[1, 2, 3, 4, 5, 6, 7, 8, 9];
    await file.writeAsBytes(bytes);

    final b64 = base64Encode(bytes);
    vm.addCard(CardModel(name: 'FileCard', monthlyCutoff: 1, rebateCutoff: 31, extraRebatePct: 5.0, quota: 100, imagePath: file.path));

    final csv = await vm.exportCsvString();
    expect(csv.contains(b64), isTrue);
    expect(csv.contains('data:image/png;base64,'), isFalse);

    // cleanup
    await file.delete();
    await tmp.delete(recursive: true);
  });
}
