// lib/viewmodels/card_viewmodel.dart
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import '../models/card_model.dart';
import '../services/card_repository.dart';
import '../utils/file_saver.dart';

class CardViewModel with ChangeNotifier {
  List<CardModel> _cards = [];
  int _currentIndex = 0;
  DateTime _debugDate = DateTime.now();
  final CardRepository repository;

  CardViewModel(this.repository) {
    _loadData();
  }

  // ── Visible cards only ────────────────────────────────────────────────
  List<CardModel> get visibleCards => _cards.where((c) => !c.isHidden).toList();

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
      // preserve expenses/presets when editing unless explicitly changed
      final existing = _cards[_currentIndex];
      final merged = CardModel(
        name: updatedCard.name,
        monthlyCutoff: updatedCard.monthlyCutoff,
        rebateCutoff: updatedCard.rebateCutoff,
        extraRebatePct: updatedCard.extraRebatePct,
        quota: updatedCard.quota,
        imagePath: updatedCard.imagePath ?? existing.imagePath,
        isHidden: updatedCard.isHidden,
        expenses: existing.expenses,
        presets: existing.presets,
      );
      _cards[_currentIndex] = merged;
      _saveData();
      notifyListeners();
    }
  }

  void deleteCard() {
    deleteCardAt(_currentIndex);
  }

  /// Delete a card at a specific index (test-friendly)
  void deleteCardAt(int index) {
    if (_cards.isEmpty || index < 0 || index >= _cards.length) return;

    _cards.removeAt(index);

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

  void addExpense(double amount, String desc, {bool saveAsPreset = false, double? rebatePct}) {
    if (currentCard == null) return;

    // Prefill rebate percent from card's default when not provided
    final pct = rebatePct ?? currentCard!.extraRebatePct;

    currentCard!.expenses.add(Expense(
      date: currentDate,
      amount: amount,
      description: desc,
      rebatePct: pct,
    ));

    if (saveAsPreset) {
      var existing = currentCard!.presets.firstWhere(
        (p) => p.description == desc && p.amount == amount,
        orElse: () => Preset(description: desc, amount: amount, rebatePct: pct),
      );
      if (!currentCard!.presets.contains(existing)) {
        currentCard!.presets.add(existing);
      } else {
        existing.frequency += 1;
        // keep preset rebatePct in sync if it was previously unset
        if (existing.rebatePct == 0.0) existing.rebatePct = pct;
      }
    }

    _saveData();
    notifyListeners();
  }

  void addFromPreset(Preset preset) {
    if (currentCard == null) return;
    addExpense(preset.amount, preset.description, rebatePct: preset.rebatePct);
    preset.frequency += 1;
    notifyListeners();
  }

  void editPreset(Preset oldPreset, String newDesc, double newAmount, double rebatePct) {
    oldPreset.description = newDesc;
    oldPreset.amount = newAmount;
    oldPreset.rebatePct = rebatePct;
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
    final periodStart = getPeriodStart(currentDate, card.monthlyCutoff);

    // Sum per-expense rebate contribution using each expense's rebatePct
    final sum = card.expenses
        .where((e) => !e.date.isBefore(periodStart))
        .fold(0.0, (double acc, e) => acc + e.amount * (e.rebatePct / 100));

    return sum.clamp(0.0, card.quota);
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

  Future<String?> exportToCsv() async {
    if (_cards.isEmpty) {
      return 'no_cards';
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

    // Presets header
    csvRows.add(['Preset', 'Card', 'Description', 'Amount', 'Extra Rebate %', 'Frequency']);

    // Presets
    for (var card in _cards) {
      for (var p in card.presets) {
        csvRows.add([card.name, p.description, p.amount, p.rebatePct, p.frequency]);
      }
    }

    // Empty line separator before expenses
    csvRows.add([]);

    // Expenses header (includes per-entry rebate percent)
    csvRows.add(Expense.csvHeader());

    // Expenses
    for (var card in _cards) {
      for (var exp in card.expenses) {
        csvRows.add(exp.toCsvList(card.name));
      }
    }

    final csv = await exportCsvStringFromRows(csvRows);

    final datetimeMinute = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());

    // Web: trigger browser download using conditional implementation
    if (kIsWeb) {
      try {
        final filename = 'masterrebate_export_$datetimeMinute.csv';
        // saveCsvAndReturn is provided by a conditional import (web or stub)
        final res = await saveCsvAndReturn(csv, filename);
        return res;
      } catch (e) {
        if (kDebugMode) debugPrint('Web save/download failed: $e');
        return 'failed';
      }
    }

    // Non-web platforms: try to use a directory picker but handle any error type
    String? path;
    bool pickerUnavailable = false;
    try {
      path = await FilePicker.platform.getDirectoryPath();
    } catch (e) {
      // Catch any error (UnimplementedError, UnsupportedError, etc.) and fallback
      if (kDebugMode) debugPrint('FilePicker.getDirectoryPath error: $e');
      pickerUnavailable = true;
      path = null;
    }

    if (path == null && pickerUnavailable) {
      // Fall back to system temp directory
      final tmp = io.Directory.systemTemp;
      final outFile = io.File('${tmp.path.replaceAll('\\', '/')}/masterrebate_export_$datetimeMinute.csv');
      await outFile.writeAsString(csv);
      return outFile.path;
    }

    if (path == null) {
      // User cancelled
      return 'cancelled';
    }

    final file = io.File('$path/masterrebate_export_$datetimeMinute.csv');
    try {
      await file.writeAsString(csv);
      return file.path;
    } catch (e) {
      if (kDebugMode) debugPrint('Write to selected path failed: $e');

      // Try Android Downloads folder first
      if (!kIsWeb) {
        try {
          if (io.Platform.isAndroid) {
            final downloadsDir = io.Directory('/storage/emulated/0/Download/masterrebate');
            if (!await downloadsDir.exists()) await downloadsDir.create(recursive: true);
            final outFile = io.File('${downloadsDir.path}/masterrebate_export_$datetimeMinute.csv');
            await outFile.writeAsString(csv);
            return outFile.path;
          }
        } catch (e2) {
          if (kDebugMode) debugPrint('Write to Downloads failed: $e2');
        }
      }

      final tmp = io.Directory.systemTemp;
      final outFile = io.File('${tmp.path.replaceAll('\\', '/')}/masterrebate_export_$datetimeMinute.csv');
      await outFile.writeAsString(csv);
      return outFile.path;
    }
  }

  /// Returns CSV string for given rows (split out for testability)
  Future<String> exportCsvStringFromRows(List<List<dynamic>> rows) async {
    return const ListToCsvConverter().convert(rows);
  }

  /// Returns CSV string for current cards (testable without file IO)
  Future<String> exportCsvString() async {
    List<List<dynamic>> csvRows = [];

    // Card headers
    csvRows.add(CardModel.csvHeader());

    // Cards
    for (var card in _cards) {
      csvRows.add(card.toCsvList());
    }

    // Empty line separator
    csvRows.add([]);

    // Presets header
    csvRows.add(['Preset', 'Card', 'Description', 'Amount', 'Extra Rebate %', 'Frequency']);

    // Presets
    for (var card in _cards) {
      for (var p in card.presets) {
        csvRows.add([card.name, p.description, p.amount, p.rebatePct, p.frequency]);
      }
    }

    // Empty line separator before expenses
    csvRows.add([]);

    // Expenses header (includes per-entry rebate percent)
    csvRows.add(Expense.csvHeader());

    // Expenses
    for (var card in _cards) {
      for (var exp in card.expenses) {
        csvRows.add(exp.toCsvList(card.name));
      }
    }

    return exportCsvStringFromRows(csvRows);
  }

  Future<String?> importFromCsv() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return 'cancelled';

    final platformFile = result.files.single;
    Uint8List? fileBytes;

    if (kIsWeb) {
      fileBytes = platformFile.bytes;
    } else {
      if (platformFile.path == null) return 'cancelled';
      fileBytes = await io.File(platformFile.path!).readAsBytes();
    }

    if (fileBytes == null) return 'cancelled';

    final csvString = utf8.decode(fileBytes);
    return importFromCsvString(csvString);
  }

  /// Import CSV content from a raw CSV string (testable)
  String? importFromCsvString(String csvString) {
    final originalRows = const CsvToListConverter().convert(csvString);
    List<List<dynamic>> rows = originalRows.map((r) => r.cast<dynamic>()).toList();

    List<CardModel> importedCards = [];
    Map<String, CardModel> cardMap = {};

    bool inExpensesSection = false;

    // Debug: inspect row shapes before fallback
    if (rows.isNotEmpty) {
      final first = rows[0];
      if (kDebugMode) {
        debugPrint('DEBUG rows.length=${rows.length}, first.length=${first.length}');
        debugPrint('DEBUG first types: ${first.map((e) => e.runtimeType).toList()}');
      }
    }

    // Fallback: some CSV sources may return a single row containing newlines
    if (rows.length == 1) {
      final first = rows[0];

      // Case A: single cell string with embedded newlines
      if (first.length == 1 && first[0] is String && first[0].toString().contains('\n')) {
        if (kDebugMode) debugPrint('Fallback: single-cell CSV detected');
        final raw = first[0].toString();
        final lines = raw.split(RegExp(r'\r?\n'));
        final parsed = <List<dynamic>>[];
        for (var line in lines) {
          if (line.trim().isEmpty) continue;
          parsed.add(line.split(',').map((c) => c.trim()).toList());
        }
        if (kDebugMode) debugPrint('Fallback: parsed into ${parsed.length} rows from single-cell');
        rows = parsed;
      }

      // Case B: CsvToListConverter produced one row but with many cells (flattened). Rebuild raw and split by newlines.
      else if (first.length > 1) {
        if (kDebugMode) debugPrint('Fallback: single-row but multiple cells detected, trying rebuild');
        final raw = first.map((e) => e?.toString() ?? '').join(',');
        final lines = raw.split(RegExp(r'\r?\n'));
        final parsed = <List<dynamic>>[];
        for (var line in lines) {
          if (line.trim().isEmpty) continue;
          parsed.add(line.split(',').map((c) => c.trim()).toList());
        }
        if (kDebugMode) debugPrint('Fallback: parsed into ${parsed.length} rows from rebuilt raw');
        rows = parsed;
      }
    }

    // Debugging: show parsed rows
    if (kDebugMode) {
      debugPrint('Parsed rows count: ${rows.length}');
      for (var r in rows) {
        debugPrint('PARSED ROW: $r');
      }
    }

    bool inPresetsSection = false;
    for (var row in rows) {
      if (row.isEmpty) continue;
      final cleaned = row.map((e) => e?.toString().trim() ?? '').toList();

      if (cleaned.isEmpty) continue;

      // Detect section change
      if (cleaned[0] == 'Preset') {
        inPresetsSection = true;
        inExpensesSection = false;
        continue;
      }

      if (cleaned[0] == 'Card' && cleaned.length >= 4 && cleaned[1] == 'Date' && cleaned[2] == 'Amount') {
        inExpensesSection = true;
        inPresetsSection = false;
        continue;
      }

      if (!inExpensesSection && !inPresetsSection) {
        // Card row (skip header-ish rows)
        final headerKeywords = ['card','name','monthly', 'rebate', 'quota', 'cutoff', 'extra', 'amount', 'date', 'description', '%'];
        final headerMatchCount = headerKeywords.fold<int>(0, (acc, k) => acc + (cleaned.any((c) => c.toLowerCase().contains(k)) ? 1 : 0));
        final looksLikeHeader = headerMatchCount >= 2; // require at least two header-like tokens to avoid false positives like card names
        if (looksLikeHeader) continue;

        if (cleaned.length >= 2 && cleaned[0].isNotEmpty) {
          try {
            final monthly = cleaned.length > 1 ? int.tryParse(cleaned[1]) ?? 1 : 1;
            final rebate = cleaned.length > 2 ? int.tryParse(cleaned[2]) ?? 1 : 1;
            final extra = cleaned.length > 3 ? double.tryParse(cleaned[3]) ?? 0.0 : 0.0;
            final quota = cleaned.length > 4 ? double.tryParse(cleaned[4]) ?? 0.0 : 0.0;

            final card = CardModel(
              name: cleaned[0],
              monthlyCutoff: monthly,
              rebateCutoff: rebate,
              extraRebatePct: extra,
              quota: quota,
            );
            importedCards.add(card);
            cardMap[card.name] = card;
          } catch (_) {}
        }
      } else if (inPresetsSection) {
        // Preset row: expected [CardName, Description, Amount, Extra Rebate %, Frequency]
        if (cleaned.length >= 3 && cleaned[0].isNotEmpty) {
          try {
            final cardName = cleaned[0];
            final desc = cleaned.length > 1 ? cleaned[1] : '';
            final amountStr = cleaned.length > 2 ? cleaned[2] : '0';
            final rebate = cleaned.length > 3 ? double.tryParse(cleaned[3]) ?? 0.0 : 0.0;
            final freq = cleaned.length > 4 ? int.tryParse(cleaned[4]) ?? 1 : 1;

            final target = cardMap[cardName];
            if (target != null) {
              final amount = double.tryParse(amountStr) ?? 0.0;
              target.presets.add(Preset(description: desc, amount: amount, frequency: freq, rebatePct: rebate));
            }
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
            final rebateStr = cleaned.length > 4 ? cleaned[4] : '';

            final target = cardMap[cardName];
            if (target != null) {
              final date = DateFormat('yyyy-MM-dd').tryParse(dateStr) ?? DateTime.now();
              final amount = double.tryParse(amountStr) ?? 0.0;
              final rebatePct = rebateStr.isNotEmpty ? double.tryParse(rebateStr) ?? target.extraRebatePct : target.extraRebatePct;
              target.expenses.add(Expense(
                date: date,
                amount: amount,
                description: desc,
                rebatePct: rebatePct,
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
      return 'Imported ${importedCards.length}';
    }

    return null;
  }

  void _saveData() {
    repository.saveCards(_cards);
  }

  void _loadData() async {
    final loaded = await repository.loadCards();
    _cards = loaded;
    _currentIndex = _cards.isNotEmpty ? 0 : 0;
    notifyListeners();
  }
}
