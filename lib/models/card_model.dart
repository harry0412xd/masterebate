// lib/models/card_model.dart
import 'package:intl/intl.dart';

class Expense {
  DateTime date;
  double amount;
  String description;

  Expense({
    required this.date,
    required this.amount,
    required this.description,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'amount': amount,
        'description': description,
      };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        date: DateTime.parse(json['date']),
        amount: json['amount'],
        description: json['description'],
      );
}

class Preset {
  String description;
  double amount;
  int frequency;

  Preset({
    required this.description,
    required this.amount,
    this.frequency = 1,
  });

  Map<String, dynamic> toJson() => {
        'description': description,
        'amount': amount,
        'frequency': frequency,
      };

  factory Preset.fromJson(Map<String, dynamic> json) => Preset(
        description: json['description'],
        amount: json['amount'],
        frequency: json['frequency'],
      );
}

class CardModel {
  String name;
  int monthlyCutoff;
  int rebateCutoff;
  double extraRebatePct;
  double quota;
  String? imagePath;
  List<Expense> expenses = [];
  List<Preset> presets = [];

  CardModel({
    required this.name,
    required this.monthlyCutoff,
    required this.rebateCutoff,
    required this.extraRebatePct,
    required this.quota,
    this.imagePath,
  });

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
        'expenses': expenses.map((e) => e.toJson()).toList(),
        'presets': presets.map((p) => p.toJson()).toList(),
      };

  factory CardModel.fromJson(Map<String, dynamic> json) {
    var card = CardModel(
      name: json['name'],
      monthlyCutoff: json['monthlyCutoff'],
      rebateCutoff: json['rebateCutoff'],
      extraRebatePct: json['extraRebatePct'],
      quota: json['quota'],
      imagePath: json['imagePath'],
    );
    card.expenses = (json['expenses'] as List)
        .map((e) => Expense.fromJson(e))
        .toList();
    card.presets = (json['presets'] as List)
        .map((p) => Preset.fromJson(p))
        .toList();
    return card;
  }
}