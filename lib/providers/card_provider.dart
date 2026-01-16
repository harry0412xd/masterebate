// lib/providers/card_provider.dart
import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import '../models/card_model.dart';

class CardProvider with ChangeNotifier {
  List<CardModel> _cards = [];
  int _currentIndex = 0;
  DateTime _debugDate = DateTime.now();
  final SharedPreferences prefs;

  CardProvider(this.prefs) {
    _loadData();
  }

  // ── Visible cards only ────────────────────────────────────────────────
  List<CardModel> get visibleCards =>
      _cards.where((c) => !c.isHidden).toList();

  // ── Current card logic (prefers visible, falls back safely) ───────────
  CardModel? get currentCard {
    if (_cards.isEmpty) return null;

    // Keep index in bounds
    if (_currentIndex < 0 || _currentIndex >= _cards.length) {
      _currentIndex = 0;
    }

    // If current card is hidden, try to switch to first visible one
    if (_cards[_currentIndex].isHidden) {
      final firstVisibleIndex = _cards.indexWhere((c) => !c.isHidden);
      if (firstVisibleIndex != -1) {
        _currentIndex = firstVisibleIndex;
      }
      // If still no visible cards, we return the hidden one only for manage screen
    }

    return _cards[_currentIndex];
  }

  List<CardModel> get cards => _cards; // full list (used in manage screen)
  int get currentIndex => _currentIndex;
  DateTime get currentDate => _debugDate;

  void setDebugDate(DateTime date) {
    _debugDate = date;
    notifyListeners();
  }

  void setCurrentIndex(int index) {
    if (index >= 0 && index < _cards.length) {
      _currentIndex = index;
      notifyListeners();
    }
  }

  void switchCard(int direction) {
    if (visibleCards.isEmpty) return;

    // Find current visible index
    int visibleIndex = visibleCards.indexWhere((c) => c == currentCard);
    if (visibleIndex == -1) visibleIndex = 0;

    visibleIndex = (visibleIndex + direction) % visibleCards.length;
    if (visibleIndex < 0) visibleIndex += visibleCards.length;

    // Map back to full list index
    _currentIndex = _cards.indexOf(visibleCards[visibleIndex]);
    notifyListeners();
  }

  void addCard(CardModel card) {
    _cards.add(card);
    _currentIndex = _cards.length - 1;
    _saveData();
    notifyListeners();
  }

  void editCard(CardModel updatedCard) {
    if (_currentIndex >= 0 && _currentIndex < _cards.length) {
      _cards[_currentIndex] = updatedCard;
      _saveData();
      notifyListeners();
    }
  }

  void deleteCard() {
    if (_cards.isEmpty || _currentIndex < 0 || _currentIndex >= _cards.length) return;

    _cards.removeAt(_currentIndex);

    // Adjust current index
    if (_cards.isEmpty) {
      _currentIndex = 0;
    } else if (_currentIndex >= _cards.length) {
      _currentIndex = _cards.length - 1;
    }

    _saveData();
    notifyListeners();
  }

  void toggleCardHidden(int index) {
    if (index < 0 || index >= _cards.length) return;

    _cards[index].isHidden = !_cards[index].isHidden;

    // If we hid the current card, try to switch to first visible
    if (_cards[index].isHidden && index == _currentIndex) {
      final firstVisible = _cards.indexWhere((c) => !c.isHidden);
      _currentIndex = firstVisible != -1 ? firstVisible : 0;
    }

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

  double getCurrentExpense(CardModel card) {
    final periodStart = getPeriodStart(currentDate, card.monthlyCutoff);
    return card.expenses
        .where((e) => !e.date.isBefore(periodStart))
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double getRebateUsed(CardModel card) {
    final expense = getCurrentExpense(card);
    final required = card.getRequiredSpend();
    if (required <= 0) return 0.0;

    final baseRebate = expense * (card.extraRebatePct / 100);
    return baseRebate.clamp(0.0, card.quota);
  }

  DateTime getPeriodStart(DateTime today, int cutoff) {
    int year = today.year;
    int month = today.month;

    if (today.day <= cutoff) {
      month--;
      if (month < 1) {
        month = 12;
        year--;
      }
    }

    // Handle months with fewer days
    int daysInMonth = DateTime(year, month + 1, 0).day;
    int day = cutoff > daysInMonth ? daysInMonth : cutoff;

    return DateTime(year, month, day);
  }

  Future<void> exportToCsv(BuildContext context) async {
    if (_cards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No cards to export')),
      );
      return;
    }

    List<List<dynamic>> csvRows = [];

    // Card headers
    csvRows.add(CardModel.csvHeader());

    // Cards
    for (var card in _cards) {
      csvRows.add(card.toCsvList());
    }

    // Empty line separator
    csvRows.add([]);

    // Expenses header
    csvRows.add(['Card', 'Date', 'Amount', 'Description']);

    // Expenses
    for (var card in _cards) {
      for (var exp in card.expenses) {
        csvRows.add(exp.toCsvList(card.name));
      }
    }

    final csv = const ListToCsvConverter().convert(csvRows);

    final path = await FilePicker.platform.getDirectoryPath();
    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export cancelled')),
      );
      return;
    }

    final datetimeMinute = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final file = io.File('$path/masterrebate_export_$datetimeMinute.csv');
    await file.writeAsString(csv);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved to ${file.path}')),
    );
  }

  Future<void> importFromCsv() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final platformFile = result.files.single;
    Uint8List? fileBytes;

    if (kIsWeb) {
      fileBytes = platformFile.bytes;
    } else {
      if (platformFile.path == null) return;
      fileBytes = await io.File(platformFile.path!).readAsBytes();
    }

    if (fileBytes == null) return;

    final csvString = utf8.decode(fileBytes);
    final rows = const CsvToListConverter().convert(csvString);

    List<CardModel> importedCards = [];
    Map<String, CardModel> cardMap = {};

    bool inExpensesSection = false;

    for (var row in rows) {
      if (row.isEmpty) continue;
      final cleaned = row.map((e) => e?.toString().trim() ?? '').toList();

      if (cleaned.isEmpty) continue;

      // Detect section change
      if (cleaned[0] == 'Card' && cleaned.length >= 4 &&
          cleaned[1] == 'Date' && cleaned[2] == 'Amount') {
        inExpensesSection = true;
        continue;
      }

      if (!inExpensesSection) {
        // Card row
        if (cleaned.length >= 5 && cleaned[0].isNotEmpty) {
          try {
            final card = CardModel(
              name: cleaned[0],
              monthlyCutoff: int.tryParse(cleaned[1]) ?? 1,
              rebateCutoff: int.tryParse(cleaned[2]) ?? 1,
              extraRebatePct: double.tryParse(cleaned[3]) ?? 0.0,
              quota: double.tryParse(cleaned[4]) ?? 0.0,
            );
            importedCards.add(card);
            cardMap[card.name] = card;
          } catch (_) {}
        }
      } else {
        // Expense row
        if (cleaned.length >= 4 && cleaned[0].isNotEmpty) {
          try {
            final cardName = cleaned[0];
            final dateStr = cleaned[1];
            final amountStr = cleaned[2];
            final desc = cleaned[3];

            final target = cardMap[cardName];
            if (target != null) {
              final date = DateFormat('yyyy-MM-dd').tryParse(dateStr) ?? DateTime.now();
              final amount = double.tryParse(amountStr) ?? 0.0;
              target.expenses.add(Expense(
                date: date,
                amount: amount,
                description: desc,
              ));
            }
          } catch (_) {}
        }
      }
    }

    if (importedCards.isNotEmpty) {
      _cards = importedCards;
      _currentIndex = 0;
      _saveData();
      notifyListeners();
    }
  }

  void _saveData() {
    prefs.setString(
      'cards',
      json.encode({'cards': _cards.map((c) => c.toJson()).toList()}),
    );
  }

  void _loadData() {
    final data = prefs.getString('cards');
    if (data != null) {
      try {
        final jsonData = json.decode(data) as Map<String, dynamic>;
        final list = jsonData['cards'] as List<dynamic>? ?? [];
        _cards = list.map((c) => CardModel.fromJson(c as Map<String, dynamic>)).toList();
      } catch (_) {
        _cards = [];
      }
    }
    _currentIndex = _cards.isNotEmpty ? 0 : 0;
    notifyListeners();
  }
}