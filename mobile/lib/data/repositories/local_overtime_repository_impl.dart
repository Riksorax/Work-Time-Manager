import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_work_time/core/utils/logger.dart';

import '../../domain/repositories/overtime_repository.dart';

/// Lokales Repository für Überstunden ohne User-ID.
/// Funktioniert auch ohne Login.
class LocalOvertimeRepositoryImpl implements OvertimeRepository {
  static const String _overtimeKey = 'local_overtime_minutes';
  static const String _overtimeDateKey = 'local_overtime_date';

  final SharedPreferences _prefs;

  LocalOvertimeRepositoryImpl(this._prefs);

  @override
  Duration getOvertime() {
    final minutes = _prefs.getInt(_overtimeKey) ?? 0;
    logger.i('[LocalOvertimeRepository] getOvertime, key: $_overtimeKey, value: $minutes min');
    return Duration(minutes: minutes);
  }

  @override
  Future<void> saveOvertime(Duration overtime) async {
    logger.i('[LocalOvertimeRepository] saveOvertime, key: $_overtimeKey, value: ${overtime.inMinutes} min');
    final success = await _prefs.setInt(_overtimeKey, overtime.inMinutes);
    logger.i('[LocalOvertimeRepository] Save success: $success');

    // Verifiziere, dass der Wert gespeichert wurde
    final savedValue = _prefs.getInt(_overtimeKey);
    logger.i('[LocalOvertimeRepository] Verification - saved value: $savedValue min');
  }

  @override
  DateTime? getLastUpdateDate() {
    final dateString = _prefs.getString(_overtimeDateKey);
    return dateString != null ? DateTime.tryParse(dateString) : null;
  }

  @override
  Future<void> saveLastUpdateDate(DateTime date) async {
    await _prefs.setString(_overtimeDateKey, date.toIso8601String());
  }
}
