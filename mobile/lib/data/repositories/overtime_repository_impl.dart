import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_work_time/core/utils/logger.dart';

import '../../domain/repositories/overtime_repository.dart';

class OvertimeRepositoryImpl implements OvertimeRepository {
  static const String _overtimeKey = 'overtime_minutes';
  static const String _overtimeDateKey = 'overtime_date';

  final SharedPreferences _prefs;
  final String _userId;

  OvertimeRepositoryImpl(this._prefs, this._userId);

  String get _userPrefKey => '${_userId}_$_overtimeKey';
  String get _userDatePrefKey => '${_userId}_$_overtimeDateKey';

  @override
  Duration getOvertime() {
    final minutes = _prefs.getInt(_userPrefKey) ?? 0;
    logger.i('[OvertimeRepository] getOvertime for userId $_userId, key: $_userPrefKey, value: $minutes min');
    return Duration(minutes: minutes);
  }

  @override
  Future<void> saveOvertime(Duration overtime) async {
    logger.i('[OvertimeRepository] saveOvertime for userId $_userId, key: $_userPrefKey, value: ${overtime.inMinutes} min');
    final success = await _prefs.setInt(_userPrefKey, overtime.inMinutes);
    logger.i('[OvertimeRepository] Save success: $success');

    // Verifiziere, dass der Wert gespeichert wurde
    final savedValue = _prefs.getInt(_userPrefKey);
    logger.i('[OvertimeRepository] Verification - saved value: $savedValue min');
  }

  @override
  DateTime? getLastUpdateDate() {
    final dateString = _prefs.getString(_userDatePrefKey);
    return dateString != null ? DateTime.tryParse(dateString) : null;
  }

  @override
  Future<void> saveLastUpdateDate(DateTime date) async {
    await _prefs.setString(_userDatePrefKey, date.toIso8601String());
  }
}
