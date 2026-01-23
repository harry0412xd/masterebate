// lib/providers/card_provider.dart
import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import '../models/card_model.dart';
import '../utils/file_saver.dart';

@Deprecated('Use CardViewModel instead')
class CardProvider {}
    _saveData();
    notifyListeners();
  }

  void addExpense(double amount, String desc, {bool saveAsPreset = false, double? rebatePct}) {
    if (currentCard == null) return;

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
        if (existing.rebatePct == 0.0) existing.rebatePct = pct;
      }
    }

    _saveData();
    notifyListeners();
  }

  void addFromPreset(Preset preset) {
    if (currentCard == null) return;
    addExpense(preset.amount, preset.description, rebatePct: preset.rebatePct);
    // Ensure frequency increment is persisted after adding expense
    preset.frequency += 1;
    _saveData();
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

  /// Returns the amount of eligible spending for the period expressed as "spend at
  /// the card's extraRebatePct". This ensures expenses with 0% (or lower) rebate do not
  /// reduce the remaining target. When the card has no extra rebate percent, return 0.0.
  double getEligibleSpending(CardModel card) {
    final periodStart = getPeriodStart(currentDate, card.monthlyCutoff);
    if (card.extraRebatePct <= 0) return 0.0;

    final sum = card.expenses
        .where((e) => !e.date.isBefore(periodStart))
        .fold(0.0, (double acc, e) => acc + e.amount * (e.rebatePct / card.extraRebatePct));

    // It doesn't make sense for eligible spending to exceed the required spend for full rebate
    final eligible = sum.clamp(0.0, card.getRequiredSpend());
    return double.parse(eligible.toStringAsFixed(2));
  }

  double getRebateUsed(CardModel card) {
    final periodStart = getPeriodStart(currentDate, card.monthlyCutoff);

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
    _currentIndex = 0;
    notifyListeners();
  }
}