import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/overtime_repository.dart';

class OvertimeRepositoryImpl implements OvertimeRepository {
  static const String _overtimeKey = 'overtime_minutes';

  final SharedPreferences _prefs;
  final String _userId;

  OvertimeRepositoryImpl(this._prefs, this._userId);

  String get _userPrefKey => '$_userId\_$_overtimeKey';

  @override
  Duration getOvertime() {
    final minutes = _prefs.getInt(_userPrefKey) ?? 0;
    print('[OvertimeRepository] getOvertime for userId $_userId, key: $_userPrefKey, value: $minutes min');
    return Duration(minutes: minutes);
  }

  @override
  Future<void> saveOvertime(Duration overtime) async {
    print('[OvertimeRepository] saveOvertime for userId $_userId, key: $_userPrefKey, value: ${overtime.inMinutes} min');
    final success = await _prefs.setInt(_userPrefKey, overtime.inMinutes);
    print('[OvertimeRepository] Save success: $success');

    // Verifiziere, dass der Wert gespeichert wurde
    final savedValue = _prefs.getInt(_userPrefKey);
    print('[OvertimeRepository] Verification - saved value: $savedValue min');
  }
}
