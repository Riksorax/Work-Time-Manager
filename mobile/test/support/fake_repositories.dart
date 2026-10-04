import 'dart:async';

import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/repositories/overtime_repository.dart';
import 'package:flutter_work_time/domain/repositories/settings_repository.dart';
import 'package:flutter_work_time/domain/repositories/work_repository.dart';

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// In-Memory-[WorkRepository] mit Speicherlog (#379). Schlüssel `yyyy-MM-dd`
/// des Tages, an dem [getWorkEntry] gefragt wurde bzw. des `entry.date`.
class FakeWorkRepository implements WorkRepository {
  final Map<String, WorkEntryEntity> store = {};

  /// Chronologisches Log aller Aufrufe: `read:<key>` / `save:<key>`.
  final List<String> log = [];

  /// Alle gespeicherten Einträge in Reihenfolge.
  final List<WorkEntryEntity> saved = [];

  int getWorkEntryCalls = 0;
  int getMonthCalls = 0;
  bool failReads = false;
  bool failSaves = false;

  /// Wenn gesetzt, wartet jeder `getWorkEntry`-Aufruf auf einen Completer.
  /// Der Completer wird in [pendingReads] abgelegt.
  bool holdReads = false;
  final List<Completer<void>> pendingReads = [];

  @override
  Future<WorkEntryEntity> getWorkEntry(DateTime date) async {
    getWorkEntryCalls++;
    final key = dayKey(date);
    log.add('read:$key');
    if (holdReads) {
      final c = Completer<void>();
      pendingReads.add(c);
      await c.future;
    }
    if (failReads) throw Exception('offline');
    return store[key] ??
        WorkEntryEntity(
            id: key, date: DateTime(date.year, date.month, date.day));
  }

  @override
  Future<void> saveWorkEntry(WorkEntryEntity entry) async {
    final key = dayKey(entry.date);
    log.add('save:$key');
    if (failSaves) throw Exception('offline');
    saved.add(entry);
    store[key] = entry;
  }

  @override
  Future<List<WorkEntryEntity>> getWorkEntriesForMonth(
      int year, int month) async {
    getMonthCalls++;
    return store.values
        .where((e) => e.date.year == year && e.date.month == month)
        .toList();
  }

  @override
  Future<void> deleteWorkEntry(String entryId) async {
    store.remove(entryId);
  }
}

/// In-Memory-[OvertimeRepository]; `saveLastUpdateDate` übernimmt den vom
/// Aufrufer gelieferten Zeitpunkt (die Uhr des ViewModels).
class FakeOvertimeRepository implements OvertimeRepository {
  Duration stored = Duration.zero;
  DateTime? lastUpdate;
  final List<Duration> savedOvertimes = [];
  bool failReads = false;

  /// Wenn gesetzt, blockiert `ensureOvertimeLoaded` bis zum Completer.
  Completer<void>? holdOvertimeLoad;

  @override
  Duration getOvertime() => stored;

  @override
  Future<void> saveOvertime(Duration overtime) async {
    stored = overtime;
    savedOvertimes.add(overtime);
  }

  @override
  DateTime? getLastUpdateDate() => lastUpdate;

  @override
  Future<void> saveLastUpdateDate(DateTime date) async {
    lastUpdate = date;
  }

  @override
  Future<Duration> ensureOvertimeLoaded() async {
    final hold = holdOvertimeLoad;
    if (hold != null) await hold.future;
    if (failReads) throw Exception('offline');
    return stored;
  }

  @override
  Future<DateTime?> ensureLastUpdateLoaded() async => lastUpdate;
}

/// Minimale Einstellungen: Mo-Fr, 40 h/Woche (also 8 h Soll Mo-Fr, 0 sonst).
class FakeSettingsRepository implements SettingsRepository {
  List<int> workdays = [1, 2, 3, 4, 5];
  double weeklyHours = 40;

  @override
  List<int> getWorkdays() => workdays;

  @override
  double getTargetWeeklyHours() => weeklyHours;

  @override
  bool getWarnOnOvertimeThreshold() => false;

  @override
  bool getWarnOnUndertimeThreshold() => false;

  @override
  double getOvertimeThresholdHours() => 0;

  @override
  double getUndertimeThresholdHours() => 0;

  @override
  String getLocale() => 'de';

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
