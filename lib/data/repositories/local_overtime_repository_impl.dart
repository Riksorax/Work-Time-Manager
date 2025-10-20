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
    return Duration(minutes: minutes);
  }

  @override
  Future<void> saveOvertime(Duration overtime) async {
    await _prefs.setInt(_overtimeKey, overtime.inMinutes);
    print('[LocalOvertimeRepository] Gespeichert: ${overtime.inMinutes} Min');
  }
}
