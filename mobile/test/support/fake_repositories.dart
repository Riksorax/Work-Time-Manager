import 'dart:async';

import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/repositories/overtime_repository.dart';
import 'package:flutter_work_time/domain/repositories/settings_repository.dart';
import 'package:flutter_work_time/domain/repositories/work_repository.dart';

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _hm(DateTime? d) => d == null
    ? '-'
    : '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// In-Memory-[WorkRepository] mit Speicherlog (#379). Schlüssel `yyyy-MM-dd`
/// des Tages, an dem [getWorkEntry] gefragt wurde bzw. des `entry.date`.
///
/// Mit [label] und [writeLog] (Profil-Tests, #388) landet jeder Write zusätzlich
/// als `<label>:entry:<yyyy-MM-dd>:<start>-<end>` im gemeinsamen Log.
class FakeWorkRepository implements WorkRepository {
  FakeWorkRepository({this.label, this.writeLog});

  final String? label;
  final List<String>? writeLog;

  final Map<String, WorkEntryEntity> store = {};

  /// Chronologisches Log aller Aufrufe: `read:<key>` / `save:<key>`.
  final List<String> log = [];

  /// Alle gespeicherten Einträge in Reihenfolge.
  final List<WorkEntryEntity> saved = [];

  int getWorkEntryCalls = 0;
  int getMonthCalls = 0;

  /// Gelesene Monate in Reihenfolge (`yyyy-MM`), für Lese-Assertions (#385).
  final List<String> monthReads = [];

  /// Monate (`yyyy-MM`), deren Lesen fehlschlägt (#385).
  final Set<String> failMonths = {};
  bool failReads = false;
  bool failSaves = false;

  /// Wenn gesetzt, wartet jeder `getWorkEntry`-Aufruf auf einen Completer.
  /// Der Completer wird in [pendingReads] abgelegt.
  bool holdReads = false;
  final List<Completer<void>> pendingReads = [];

  /// Wenn gesetzt, wartet jeder `saveWorkEntry`-Aufruf (vor dem Eintragen in
  /// [store]/[saved]) auf einen Completer aus [pendingSaves].
  bool holdSaves = false;
  final List<Completer<void>> pendingSaves = [];

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
    if (holdSaves) {
      final c = Completer<void>();
      pendingSaves.add(c);
      await c.future;
    }
    if (failSaves) throw Exception('offline');
    saved.add(entry);
    store[key] = entry;
    if (label != null) {
      writeLog?.add(
          '$label:entry:$key:${_hm(entry.workStart)}-${_hm(entry.workEnd)}');
    }
  }

  @override
  Future<List<WorkEntryEntity>> getWorkEntriesForMonth(
      int year, int month) async {
    getMonthCalls++;
    final monthKey =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
    monthReads.add(monthKey);
    if (holdReads) {
      final c = Completer<void>();
      pendingReads.add(c);
      await c.future;
    }
    if (failReads || failMonths.contains(monthKey)) {
      throw Exception('offline');
    }
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
///
/// Mit [label] und [writeLog] (#388): `<label>:overtime:<minuten>` bzw.
/// `<label>:lastUpdate`.
class FakeOvertimeRepository implements OvertimeRepository {
  FakeOvertimeRepository({this.label, this.writeLog, this.serverNow});

  final String? label;
  final List<String>? writeLog;

  /// Bildet das Backend nach (#406): Wenn gesetzt, setzt `saveOvertime` ohne
  /// `keepLastUpdated` `lastUpdate = serverNow()` (wie `PUT /api/overtime`),
  /// mit `keepLastUpdated: true` bleibt `lastUpdate` unverändert. Ohne
  /// [serverNow] setzt `saveOvertime` `lastUpdate` nie (Local-Verhalten).
  final DateTime Function()? serverNow;

  Duration stored = Duration.zero;
  DateTime? lastUpdate;
  final List<Duration> savedOvertimes = [];

  /// Parallel zu [savedOvertimes]: das übergebene `keepLastUpdated`.
  final List<bool> savedKeepLastUpdated = [];
  bool failReads = false;

  /// Wenn gesetzt, blockiert `ensureOvertimeLoaded` bis zum Completer.
  Completer<void>? holdOvertimeLoad;

  /// Wenn gesetzt, wartet jeder `saveOvertime`-Aufruf auf einen Completer aus
  /// [pendingOvertimeSaves] (Wert wird erst danach gespeichert).
  bool holdSaveOvertime = false;
  final List<Completer<void>> pendingOvertimeSaves = [];

  /// Wenn gesetzt, wirft `saveOvertime`.
  bool failSaveOvertime = false;

  /// Anzahl der `saveOvertime`-Aufrufe (auch der scheiternden), 1-basiert (#410).
  int saveOvertimeCalls = 0;

  /// Nummern (1-basiert) der `saveOvertime`-Aufrufe, die werfen sollen, z. B.
  /// `{2}` für "nur der zweite Aufruf" (#410). Default: keiner.
  final Set<int> failSaveOvertimeCalls = {};

  @override
  Duration getOvertime() => stored;

  @override
  Future<void> saveOvertime(Duration overtime,
      {bool keepLastUpdated = false}) async {
    final callNo = ++saveOvertimeCalls;
    if (holdSaveOvertime) {
      final c = Completer<void>();
      pendingOvertimeSaves.add(c);
      await c.future;
    }
    if (failSaveOvertime || failSaveOvertimeCalls.contains(callNo)) {
      throw Exception('offline');
    }
    stored = overtime;
    savedOvertimes.add(overtime);
    savedKeepLastUpdated.add(keepLastUpdated);
    if (label != null) writeLog?.add('$label:overtime:${overtime.inMinutes}');
    final backendNow = serverNow;
    if (backendNow != null && !keepLastUpdated) {
      lastUpdate = backendNow();
      if (label != null) writeLog?.add('$label:lastUpdate');
    }
  }

  @override
  DateTime? getLastUpdateDate() => lastUpdate;

  @override
  Future<void> saveLastUpdateDate(DateTime date) async {
    lastUpdate = date;
    if (label != null) writeLog?.add('$label:lastUpdate');
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

  /// Schwellwert-Warnungen (#219), Default: aus.
  bool warnOnOvertime = false;
  double overtimeThresholdHours = 0;
  bool warnOnUndertime = false;
  double undertimeThresholdHours = 0;

  @override
  List<int> getWorkdays() => workdays;

  @override
  double getTargetWeeklyHours() => weeklyHours;

  @override
  bool getWarnOnOvertimeThreshold() => warnOnOvertime;

  @override
  bool getWarnOnUndertimeThreshold() => warnOnUndertime;

  @override
  double getOvertimeThresholdHours() => overtimeThresholdHours;

  @override
  double getUndertimeThresholdHours() => undertimeThresholdHours;

  @override
  String getLocale() => 'de';

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
