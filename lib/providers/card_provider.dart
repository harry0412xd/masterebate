// lib/providers/card_provider.dart
import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../models/card_model.dart';
import '../services/google_service.dart';

class CardProvider with ChangeNotifier {
  List<CardModel> _cards = [];
  int _currentIndex = 0;
  DateTime _debugDate = DateTime.now();
  final SharedPreferences prefs;

  CardProvider(this.prefs) {
    _loadData();
  }

  List<CardModel> get cards => _cards;
  int get currentIndex => _currentIndex;
  CardModel? get currentCard =>
      _cards.isNotEmpty ? _cards[_currentIndex] : null;
  DateTime get currentDate => _debugDate;

  void setDebugDate(DateTime date) {
    _debugDate = date;
    notifyListeners();
  }

  void switchCard(int direction) {
    if (_cards.isEmpty) return;
    _currentIndex = (_currentIndex + direction) % _cards.length;
    if (_currentIndex < 0) _currentIndex += _cards.length;
    notifyListeners();
  }

  void addCard(CardModel card) {
    _cards.add(card);
    _currentIndex = _cards.length - 1;
    _saveData();
    notifyListeners();
  }

  void editCard(CardModel updatedCard) {
    _cards[_currentIndex] = updatedCard;
    _saveData();
    notifyListeners();
  }

  void deleteCard() {
    if (_cards.isEmpty) return;
    _cards.removeAt(_currentIndex);
    _currentIndex = _currentIndex > 0 ? _currentIndex - 1 : 0;
    _saveData();
    notifyListeners();
  }

  void addExpense(double amount, String desc, {bool saveAsPreset = false}) {
    if (currentCard == null) return;
    currentCard!.expenses.add(Expense(
      date: currentDate,
      amount: amount,
      description: desc,
    ));
    if (saveAsPreset) {
      var existing = currentCard!.presets.firstWhere(
        (p) => p.description == desc && p.amount == amount,
        orElse: () => Preset(description: desc, amount: amount),
      );
      if (!currentCard!.presets.contains(existing)) {
        currentCard!.presets.add(existing);
      } else {
        existing.frequency += 1;
      }
    }
    _saveData();
    notifyListeners();
  }

  void addFromPreset(Preset preset) {
    if (currentCard == null) return;
    addExpense(preset.amount, preset.description);
    preset.frequency += 1;
    notifyListeners();
  }

  void editPreset(Preset oldPreset, String newDesc, double newAmount) {
    oldPreset.description = newDesc;
    oldPreset.amount = newAmount;
    _saveData();
    notifyListeners();
  }

  void deletePreset(Preset preset) {
    if (currentCard == null) return;
    currentCard!.presets.remove(preset);
    _saveData();
    notifyListeners();
  }

  DateTime _getPeriodStart(DateTime today, int cutoff) {
    int year = today.year;
    int month = today.month;
    int day = cutoff + 1;

    if (today.day <= cutoff) {
      month -= 1;
      if (month < 1) {
        month = 12;
        year -= 1;
      }
    }

    final lastDayOfMonth = DateTime(year, month + 1, 0).day;
    if (day > lastDayOfMonth) day = lastDayOfMonth;

    return DateTime(year, month, day);
  }

  double getCurrentExpense(CardModel card) {
    final today = currentDate;
    final start = _getPeriodStart(today, card.monthlyCutoff);
    return card.expenses
        .where((e) => !e.date.isBefore(start))
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double getRebateUsed(CardModel card) {
    final today = currentDate;
    final start = _getPeriodStart(today, card.rebateCutoff);
    return card.expenses
        .where((e) => !e.date.isBefore(start))
        .fold(0.0, (sum, e) => sum + e.amount * card.extraRebatePct / 100);
  }

  Future<void> pickCardImage() async {
    if (currentCard == null) return;
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      currentCard!.imagePath = image.path;
      _saveData();
      notifyListeners();
    }
  }

  Future<void> exportToCsv() async {
    List<List<dynamic>> rows = [
      ['Card', 'Date', 'Amount', 'Description']
    ];
    for (var card in _cards) {
      for (var exp in card.expenses) {
        rows.add([
          card.name,
          DateFormat('yyyy-MM-dd').format(exp.date),
          exp.amount,
          exp.description,
        ]);
      }
    }
    String csv = const ListToCsvConverter().convert(rows);

    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Expenses CSV',
      fileName: 'credit_card_expenses_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (outputFile != null) {
      io.File file = io.File(outputFile);
      await file.writeAsString(csv);
    }
  }

  Future<void> importFromCsv() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result != null && result.files.single.path != null) {
      io.File file = io.File(result.files.single.path!);
      String csvString = await file.readAsString();
      List<List<dynamic>> rows = const CsvToListConverter().convert(csvString);
      if (rows.isEmpty || rows[0][0] != 'Card') return;
      await _processImportedData(rows.skip(1).toList());
    }
  }

  Future<void> exportToGoogleSheets(BuildContext context) async {
    List<Map<String, dynamic>> data = [];
    for (var card in _cards) {
      for (var exp in card.expenses) {
        data.add({
          'card': card.name,
          'date': DateFormat('yyyy-MM-dd').format(exp.date),
          'amount': exp.amount,
          'desc': exp.description,
        });
      }
    }
    String? sheetId = await GoogleService.exportExpenses(data);
    if (sheetId != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported! https://docs.google.com/spreadsheets/d/$sheetId'),
          duration: const Duration(seconds: 10),
        ),
      );
    }
  }

  Future<void> importFromGoogleSheets(String sheetId) async {
    List<Map<String, dynamic>>? data = await GoogleService.importExpenses(sheetId);
    if (data != null) {
      await _processImportedData(data.map((e) => [e['card'], e['date'], e['amount'], e['desc']]).toList());
    }
  }

  Future<void> _processImportedData(List<List<dynamic>> rows) async {
    for (var row in rows) {
      if (row.length < 4) continue;
      String cardName = row[0].toString();
      DateTime? date;
      try {
        date = DateFormat('yyyy-MM-dd').parse(row[1].toString());
      } catch (_) {
        continue;
      }
      double amount;
      try {
        amount = double.parse(row[2].toString());
      } catch (_) {
        continue;
      }
      String desc = row[3].toString();

      var card = _cards.firstWhere(
        (c) => c.name == cardName,
        orElse: () => CardModel(
          name: cardName,
          monthlyCutoff: 1,
          rebateCutoff: 1,
          extraRebatePct: 0.0,
          quota: 0.0,
        ),
      );
      if (!_cards.contains(card)) _cards.add(card);
      card.expenses.add(Expense(date: date, amount: amount, description: desc));
    }
    _saveData();
    notifyListeners();
  }

  void _saveData() {
    prefs.setString(
      'cards',
      json.encode({'cards': _cards.map((c) => c.toJson()).toList()}),
    );
  }

  void _loadData() {
    String? data = prefs.getString('cards');
    if (data != null) {
      Map<String, dynamic> jsonData = json.decode(data);
      _cards = (jsonData['cards'] as List)
          .map((c) => CardModel.fromJson(c))
          .toList();
    }
    _currentIndex = _cards.isNotEmpty ? 0 : 0;
    notifyListeners();
  }
}