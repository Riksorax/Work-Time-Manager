import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/ishared_pres_repository.dart';

class SharedPrefsRepositories implements ISharedPrefsRepository{
  @override
  Future<SharedPreferences> getPrefs() async{
    return await SharedPreferences.getInstance();
  }

  @override
  Future<bool?> getBool(String key) async{
    var prefs = await getPrefs();
    return prefs.getBool(key);
  }

  @override
  Future<bool> setBool(String key, bool value) async{
    var prefs = await getPrefs();
    return await prefs.setBool(key, value);
  }

  @override
  Future<int?> getInt(String key) async{
    var prefs = await getPrefs();
    return prefs.getInt(key);
  }

  @override
  Future<bool> setInt(String key, int value) async{
    var prefs = await getPrefs();
    return await prefs.setInt(key, value);
  }

  @override
  Future<String?> getString(String key) async{
    var prefs = await getPrefs();
    return prefs.getString(key);
  }

  @override
  Future<bool> setString(String key, String value) async{
    var prefs = await getPrefs();
    return await prefs.setString(key, value);
  }
}