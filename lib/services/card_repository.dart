// lib/services/card_repository.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/card_model.dart';

class CardRepository {
  final SharedPreferences prefs;
  CardRepository(this.prefs);

  Future<List<CardModel>> loadCards() async {
    final data = prefs.getString('cards');
    if (data == null) return [];

    try {
      final jsonData = json.decode(data) as Map<String, dynamic>;
      final list = jsonData['cards'] as List<dynamic>? ?? [];
      return list.map((c) => CardModel.fromJson(c as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveCards(List<CardModel> cards) async {
    await prefs.setString('cards', json.encode({'cards': cards.map((c) => c.toJson()).toList()}));
  }
}
