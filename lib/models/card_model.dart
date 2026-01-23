// lib/models/card_model.dart
import 'package:intl/intl.dart';

class Expense {
  DateTime date;
  double amount;
  String description;
  double rebatePct; // per-entry rebate percentage (prefilled from card)

  Expense({
    required this.date,
    required this.amount,
    required this.description,
    this.rebatePct = 0.0,
  });

  static List csvHeader() {
    return [
      'Card',
      'Date',
      'Amount',
      'Description',
      'Extra Rebate %',
    ];
  }

  List toCsvList(String cardName) {
    return [
      cardName,
      DateFormat('yyyy-MM-dd').format(date),
      amount,
      description,
      rebatePct,
    ];
  }

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'amount': amount,
        'description': description,
        'rebatePct': rebatePct,
      };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        date: DateTime.parse(json['date']),
        amount: (json['amount'] as num).toDouble(),
        description: json['description'],
        rebatePct: json['rebatePct'] != null ? (json['rebatePct'] as num).toDouble() : 0.0,
      );

}

class Preset {
  String description;
  double amount;
  int frequency;
  double rebatePct;

  Preset({
    required this.description,
    required this.amount,
    this.frequency = 1,
    this.rebatePct = 0.0,
  });

  Map<String, dynamic> toJson() => {
        'description': description,
        'amount': amount,
        'frequency': frequency,
        'rebatePct': rebatePct,
      };

  factory Preset.fromJson(Map<String, dynamic> json) => Preset(
        description: json['description'],
        amount: (json['amount'] as num).toDouble(),
        frequency: json['frequency'] ?? 1,
        rebatePct: json['rebatePct'] != null ? (json['rebatePct'] as num).toDouble() : 0.0,
      );
}

class CardModel {
  String name;
  int monthlyCutoff;
  int rebateCutoff;
  double extraRebatePct;
  double quota;
  String? imagePath;
  bool isHidden;
  List<Expense> expenses;
  List<Preset> presets;
  
  CardModel({
    required this.name,
    required this.monthlyCutoff,
    required this.rebateCutoff,
    required this.extraRebatePct,
    required this.quota,
    this.imagePath,
    this.isHidden = false,
    List<Expense>? expenses,
    List<Preset>? presets,
  })  : expenses = expenses ?? [],
        presets = presets ?? [];



  double getRequiredSpend() {
    if (extraRebatePct <= 0) return 0.0;
    return double.parse((quota / (extraRebatePct / 100)).toStringAsFixed(2));
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'monthlyCutoff': monthlyCutoff,
        'rebateCutoff': rebateCutoff,
        'extraRebatePct': extraRebatePct,
        'quota': quota,
        'imagePath': imagePath,
        'isHidden': isHidden,
        'expenses': expenses.map((e) => e.toJson()).toList(),
        'presets': presets.map((p) => p.toJson()).toList(),
      };

  factory CardModel.fromJson(Map<String, dynamic> json) {
    return CardModel(
      name: json['name'],
      monthlyCutoff: json['monthlyCutoff'],
      rebateCutoff: json['rebateCutoff'],
      extraRebatePct: json['extraRebatePct'],
      quota: json['quota'],
      imagePath: json['imagePath'],
      isHidden: json['isHidden'] ?? false,
      expenses: (json['expenses'] as List<dynamic>?)
              ?.map((e) => Expense.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      presets: (json['presets'] as List<dynamic>?)
              ?.map((p) => Preset.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }


  static List csvHeader() {
    return [
      'Card Name',
      'Monthly Cutoff',
      'Rebate Cutoff',
      'Extra Rebate %',
      'Quota',
      'Image'
    ];
  }

  List toCsvList() {
    return [
      name,
      monthlyCutoff,
      rebateCutoff,
      extraRebatePct,
      quota,
      imagePath ?? ''
    ];
  }

  factory CardModel.fromCsvRow(String csvRow, String headerRow) {
    final headers = headerRow.split(',');
    final values = csvRow.split(',');
    final imageb64 = values[headers.indexOf('Image')];
    return CardModel(
      name: values[headers.indexOf('name')],
      monthlyCutoff: int.parse(values[headers.indexOf('monthlyCutoff')]),
      rebateCutoff: int.parse(values[headers.indexOf('rebateCutoff')]),
      extraRebatePct: double.parse(values[headers.indexOf('extraRebatePct')]),
      quota: double.parse(values[headers.indexOf('quota')]),
      
    );
  }

}