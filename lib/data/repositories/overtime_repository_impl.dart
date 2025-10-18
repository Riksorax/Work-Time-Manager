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
    return Duration(minutes: minutes);
  }

  @override
  Future<void> saveOvertime(Duration overtime) async {
    await _prefs.setInt(_userPrefKey, overtime.inMinutes);
  }
}
