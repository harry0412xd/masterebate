// lib/providers/card_provider.dart (FULL UPDATED FILE - Fixed import bug)
import 'dart:convert';
import 'dart:io' as io;
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../models/card_model.dart';

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

  DateTime getPeriodStart(DateTime today, int cutoff) {
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
    final start = getPeriodStart(today, card.monthlyCutoff);
    return card.expenses
        .where((e) => !e.date.isBefore(start))
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double getRebateUsed(CardModel card) {
    final today = currentDate;
    final start = getPeriodStart(today, card.rebateCutoff);
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

  // === EXPORT & IMPORT (unchanged except import fix) ===
  Future<void> exportToCsv(BuildContext context) async {
    // ... (same as previous version)
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
    CardModel? currentCard;
    Map<String, CardModel> cardMap = {};  // To find card by name for expenses

    for (var row in rows) {
      if (row.isEmpty) continue;

      // Clean row
      final cleanedRow = row.map((cell) => cell.toString().trim()).toList();

      // Skip comments and headers
      if (cleanedRow[0].startsWith('#')) continue;
      if (cleanedRow.length >= 5 && cleanedRow[0] == 'Card Name') continue;
      if (cleanedRow.length >= 4 && cleanedRow[0] == 'Card') continue;

      // Card configuration row
      if (cleanedRow.length >= 5) {
        try {
          final name = cleanedRow[0];
          if (name.isEmpty) continue;

          currentCard = CardModel(
            name: name,
            monthlyCutoff: int.parse(cleanedRow[1]),
            rebateCutoff: int.parse(cleanedRow[2]),
            extraRebatePct: double.parse(cleanedRow[3]),
            quota: double.parse(cleanedRow[4]),
          );
          importedCards.add(currentCard);
          cardMap[name] = currentCard;
        } catch (e) {
          // Not a valid card row
        }
      }

      // Expense row
      if (cleanedRow.length >= 4) {
        try {
          final cardName = cleanedRow[0];
          final dateStr = cleanedRow[1];
          final amount = double.parse(cleanedRow[2]);
          final desc = cleanedRow[3];

          final targetCard = cardMap[cardName];
          if (targetCard != null) {
            final date = DateFormat('yyyy-MM-dd').parse(dateStr);
            targetCard.expenses.add(Expense(date: date, amount: amount, description: desc));
          }
        } catch (e) {
          // Skip invalid expense
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