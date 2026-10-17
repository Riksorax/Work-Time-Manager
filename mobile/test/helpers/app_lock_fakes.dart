import 'package:flutter_work_time/core/services/app_lock_store.dart';

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

/// Store mit Aufrufprotokoll (Reihenfolge von Lesen und Schreiben).
/// [throwOnGetString] simuliert einen Hard-Kill beim Lesen des Hashs. Eine
/// verzögerte Persistenz (z. B. für Doppeltipp-Tests) lässt sich über
/// `FakeAppLockBackend.holdWrites` simulieren.
class RecordingAppLockStore extends AppLockStore {
  final List<String> log = [];
  final String? throwOnGetString;

  RecordingAppLockStore(super.backend, {super.initial, this.throwOnGetString});

  @override
  String? getString(String key) {
    log.add('getString:$key');
    if (key == throwOnGetString) throw StateError('hard kill');
    return super.getString(key);
  }

  @override
  Future<void> setInt(String key, int value, {bool rollbackOnError = false}) {
    log.add('setInt:$key=$value');
    return super.setInt(key, value, rollbackOnError: rollbackOnError);
  }
}
