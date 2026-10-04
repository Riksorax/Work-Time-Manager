import 'package:shared_preferences/shared_preferences.dart';

/// Veränderbare Uhr für die App-Sperre (liefert UTC).
class FakeClock {
  DateTime current;
  FakeClock([DateTime? start])
      : current = start ?? DateTime.utc(2026, 1, 15, 12);

  DateTime call() => current;
  void advance(Duration d) => current = current.add(d);
  void set(DateTime t) => current = t;
}

/// Veränderbare monotone Uhr.
class FakeMonotonic {
  Duration current = Duration.zero;
  Duration call() => current;
  void advance(Duration d) => current += d;
}

/// Delegiert an echte (Mock-)Prefs und protokolliert die Aufrufreihenfolge.
/// [throwOnGetString] simuliert einen Hard-Kill beim Lesen des Hashs.
class RecordingSharedPreferences implements SharedPreferences {
  final SharedPreferences inner;
  final List<String> log = [];
  final String? throwOnGetString;

  /// Optional: verzögert setInt (z. B. für Doppeltipp-Tests).
  Future<void>? setIntDelay;

  RecordingSharedPreferences(this.inner, {this.throwOnGetString});

  @override
  String? getString(String key) {
    log.add('getString:$key');
    if (key == throwOnGetString) throw StateError('hard kill');
    return inner.getString(key);
  }

  @override
  int? getInt(String key) => inner.getInt(key);

  @override
  bool? getBool(String key) => inner.getBool(key);

  @override
  Object? get(String key) => inner.get(key);

  @override
  Set<String> getKeys() => inner.getKeys();

  @override
  bool containsKey(String key) => inner.containsKey(key);

  @override
  Future<bool> setInt(String key, int value) async {
    log.add('setInt:$key=$value');
    final delay = setIntDelay;
    if (delay != null) await delay;
    return inner.setInt(key, value);
  }

  @override
  Future<bool> setString(String key, String value) {
    log.add('setString:$key');
    return inner.setString(key, value);
  }

  @override
  Future<bool> setBool(String key, bool value) {
    log.add('setBool:$key');
    return inner.setBool(key, value);
  }

  @override
  Future<bool> remove(String key) {
    log.add('remove:$key');
    return inner.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
