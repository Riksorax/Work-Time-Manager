import 'package:shared_preferences/shared_preferences.dart';

abstract class ISharedPrefsRepository{
  Future<SharedPreferences> getPrefs();

  Future<int?> getInt(String key);

  Future<void> setInt(String key, int value);

  Future<bool?> getBool(String key);

  Future<bool> setBool(String key, bool value);

  Future<String?> getString(String key);

  Future<bool> setString(String key, String value);
}