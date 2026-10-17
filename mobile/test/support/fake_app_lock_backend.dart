import 'dart:async';

import 'package:flutter_work_time/core/services/app_lock_store.dart';

/// In-Memory-Backend für den App-Sperre-Speicher (siehe #375) mit
/// Fehlerinjektion und Schreib-Log. Ersetzt in Tests `flutter_secure_storage`.
class FakeAppLockBackend implements AppLockBackend {
  final Map<String, String> data;

  /// Reihenfolge der Aufrufe: `readAll`, `write:<key>`, `delete:<key>`.
  final List<String> log = [];

  /// Schlüssel, deren `write` wirft.
  final Set<String> failWriteKeys = {};

  /// Schlüssel, deren `delete` wirft.
  final Set<String> failDeleteKeys = {};

  /// Lässt jedes `write` werfen.
  bool failAllWrites = false;

  /// Anzahl der nächsten `readAll`-Aufrufe, die werfen.
  int failReads = 0;

  /// Schlüssel, deren Wert beim Schreiben verfälscht abgelegt wird
  /// (simuliert einen Rücklese-Mismatch).
  final Set<String> corruptKeys = {};

  /// Hält `readAll` an, bis der Completer beendet ist.
  Completer<void>? holdReads;

  /// Hält `write` an, bis der Completer beendet ist.
  Completer<void>? holdWrites;

  FakeAppLockBackend([Map<String, String>? initial]) : data = {...?initial};

  int get readCount => log.where((e) => e == 'readAll').length;
  List<String> get writes => log.where((e) => e.startsWith('write:')).toList();

  @override
  Future<Map<String, String>> readAll() async {
    log.add('readAll');
    final hold = holdReads;
    if (hold != null) await hold.future;
    if (failReads > 0) {
      failReads--;
      throw StateError('read failed');
    }
    return {...data};
  }

  @override
  Future<void> write(String key, String value) async {
    log.add('write:$key');
    final hold = holdWrites;
    if (hold != null) await hold.future;
    if (failAllWrites || failWriteKeys.contains(key)) {
      throw StateError('write failed');
    }
    data[key] = corruptKeys.contains(key) ? '$value#corrupt' : value;
  }

  @override
  Future<void> delete(String key) async {
    log.add('delete:$key');
    if (failDeleteKeys.contains(key)) throw StateError('delete failed');
    data.remove(key);
  }
}
