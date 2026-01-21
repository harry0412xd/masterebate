// lib/providers/card_provider.dart
// Deprecated shim for old `CardProvider`.
// Use `CardViewModel` in `lib/viewmodels/card_viewmodel.dart` instead.

import 'package:shared_preferences/shared_preferences.dart';
import '../services/card_repository.dart';
import '../viewmodels/card_viewmodel.dart';

class CardProvider extends CardViewModel {
  CardProvider(SharedPreferences prefs) : super(CardRepository(prefs));
}
