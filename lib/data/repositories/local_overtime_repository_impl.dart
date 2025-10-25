import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/overtime_repository.dart';

/// Lokales Repository für Überstunden ohne User-ID.
/// Funktioniert auch ohne Login.
class LocalOvertimeRepositoryImpl implements OvertimeRepository {
  static const String _overtimeKey = 'local_overtime_minutes';

  final SharedPreferences _prefs;

  LocalOvertimeRepositoryImpl(this._prefs);

  @override
  Duration getOvertime() {
    final minutes = _prefs.getInt(_overtimeKey) ?? 0;
    print('[LocalOvertimeRepository] getOvertime, key: $_overtimeKey, value: $minutes min');
    return Duration(minutes: minutes);
  }

  @override
  Future<void> saveOvertime(Duration overtime) async {
    print('[LocalOvertimeRepository] saveOvertime, key: $_overtimeKey, value: ${overtime.inMinutes} min');
    final success = await _prefs.setInt(_overtimeKey, overtime.inMinutes);
    print('[LocalOvertimeRepository] Save success: $success');

    // Verifiziere, dass der Wert gespeichert wurde
    final savedValue = _prefs.getInt(_overtimeKey);
    print('[LocalOvertimeRepository] Verification - saved value: $savedValue min');
  }
}
