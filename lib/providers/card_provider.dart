// lib/providers/card_provider.dart (FULL UPDATED FILE - fixed import/export for web)
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

  // === EXPORT CSV (full backup - works on web & mobile) ===
  Future<void> exportToCsv(BuildContext context) async {
    List<List<dynamic>> rows = [
      ['# Card Configuration'],
      ['Card Name', 'Monthly Cutoff', 'Rebate Cutoff', 'Extra Rebate %', 'Quota'],
    ];

    for (var card in _cards) {
      rows.add([
        card.name,
        card.monthlyCutoff,
        card.rebateCutoff,
        card.extraRebatePct,
        card.quota,
      ]);
    }

    rows.add(['']); // blank line
    rows.add(['# Expenses']);
    rows.add(['Card', 'Date', 'Amount', 'Description']);

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
    Uint8List bytes = Uint8List.fromList(utf8.encode(csv));
    final fileName = 'credit_card_tracker_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';

    if (kIsWeb) {
      // Web: direct browser download
      final blob = html.Blob([bytes], 'text/csv');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Full backup downloaded')),
        );
      }
    } else {
      // Mobile: share via native share sheet
      final xFile = XFile.fromData(bytes, name: fileName, mimeType: 'text/csv');
      await Share.shareXFiles(
        [xFile],
        text: 'Credit Card Tracker Backup',
        subject: 'Full Export - $fileName',
      );
    }
  }

  // === IMPORT CSV (full backup - works on web & mobile) ===
  Future<void> importFromCsv() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true, // Important for web: loads bytes directly
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

    for (var row in rows) {
      if (row.isEmpty) continue;

      // Card configuration section
      if (row.length >= 5 &&
          row[0] is String &&
          row[0].toString().trim() != '# Card Configuration' &&
          row[0].toString().trim() != 'Card Name') {
        try {
          currentCard = CardModel(
            name: row[0].toString().trim(),
            monthlyCutoff: int.parse(row[1].toString()),
            rebateCutoff: int.parse(row[2].toString()),
            extraRebatePct: double.parse(row[3].toString()),
            quota: double.parse(row[4].toString()),
          );
          importedCards.add(currentCard);
        } catch (e) {
          // skip invalid card row
        }
      }

      // Expenses section
      if (row.length >= 4 &&
          row[0] is String &&
          row[0].toString().trim() == 'Card') {
        continue; // header
      }
      if (row.length >= 4 && currentCard != null) {
        try {
          final dateStr = row[1].toString().trim();
          final date = DateFormat('yyyy-MM-dd').parse(dateStr);
          final amount = double.parse(row[2].toString());
          final desc = row[3].toString().trim();
          currentCard.expenses.add(Expense(date: date, amount: amount, description: desc));
        } catch (e) {
          // skip invalid expense row
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