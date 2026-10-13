import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/review_prompt_repository.dart';

/// SharedPreferences-Implementierung des Bewertungsanfrage-Zustands. Rein
/// lokal, unabhängig von Login und Profil.
class ReviewPromptRepositoryImpl implements ReviewPromptRepository {
  static const firstUseDateKey = 'first_use_date';
  static const promptShownKey = 'review_prompt_shown';

  final SharedPreferences _prefs;

  ReviewPromptRepositoryImpl(this._prefs);

  @override
  DateTime? getFirstUseDate() {
    final raw = _prefs.getString(firstUseDateKey);
    if (raw == null) return null;
    final parts = raw.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  @override
  Future<void> saveFirstUseDateIfAbsent(DateTime date) async {
    if (_prefs.containsKey(firstUseDateKey)) return;
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    await _prefs.setString(firstUseDateKey, '${date.year}-$mm-$dd');
  }

  @override
  bool wasPrompted() => _prefs.getBool(promptShownKey) ?? false;

  @override
  Future<void> markPrompted() async {
    await _prefs.setBool(promptShownKey, true);
  }
}
