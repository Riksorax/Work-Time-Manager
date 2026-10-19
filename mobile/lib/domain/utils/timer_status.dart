/// Reine Momentaufnahme des Timer-Zustands für Anzeigen außerhalb der App
/// (Status-Widget #276, ggf. Notification-Text). Kein zweiter Rechenweg: das
/// Netto kommt als Parameter vom Dashboard (`actualWorkDuration ?? elapsedTime`).
library;

import 'package:equatable/equatable.dart';

import '../entities/work_entry_entity.dart';
import 'entry_day.dart';

enum TimerStatus { notStarted, running, paused, stopped }

class TimerSnapshot extends Equatable {
  final TimerStatus status;

  /// Kalendertag des Eintrags (`yyyy-MM-dd`, aus [entryDayKey], #418).
  final String dayKey;

  /// Startzeit als Epoch-Millisekunden (`null` bei [TimerStatus.notStarted]).
  final int? workStartMs;

  /// Beginn der offenen Pause als Epoch-Millisekunden (nur bei
  /// [TimerStatus.paused]).
  final int? pauseStartMs;

  /// Netto-Arbeitszeit in vollen Minuten (nie negativ).
  final int netMinutes;

  /// Tagessoll in Minuten (`null`, wenn unbekannt).
  final int? targetMinutes;

  /// Summe der abgeschlossenen Pausen in Minuten.
  final int breakMinutes;

  /// Voraussichtlicher Feierabend (Tagesziel erreicht) als Epoch-Millisekunden.
  final int? expectedEndMs;

  /// Ende des Eintrags als Epoch-Millisekunden (nur bei [TimerStatus.stopped]).
  final int? workEndMs;

  /// Gesamtbilanz der Überstunden in Minuten (`null`, wenn unbekannt).
  final int? overtimeMinutes;

  const TimerSnapshot({
    required this.status,
    required this.dayKey,
    this.workStartMs,
    this.pauseStartMs,
    this.netMinutes = 0,
    this.targetMinutes,
    this.breakMinutes = 0,
    this.expectedEndMs,
    this.workEndMs,
    this.overtimeMinutes,
  });

  @override
  List<Object?> get props => [
        status,
        dayKey,
        workStartMs,
        pauseStartMs,
        netMinutes,
        targetMinutes,
        breakMinutes,
        expectedEndMs,
        workEndMs,
        overtimeMinutes,
      ];
}

/// Baut den Snapshot aus [entry] und der bereits berechneten Netto-Dauer [net].
///
/// Status: kein Start -> `notStarted`; Ende gesetzt -> `stopped`; offene Pause
/// -> `paused`; sonst `running`.
///
/// [target] (Tagessoll), [expectedEnd] (voraussichtlicher Feierabend) und
/// [totalOvertime] (Gesamtbilanz) kommen vom Dashboard und sind optional.
TimerSnapshot buildTimerSnapshot({
  required WorkEntryEntity entry,
  required Duration net,
  Duration? target,
  DateTime? expectedEnd,
  Duration? totalOvertime,
}) {
  final start = entry.workStart;
  final openBreaks = entry.breaks.where((b) => b.end == null);

  final TimerStatus status;
  if (start == null) {
    status = TimerStatus.notStarted;
  } else if (entry.workEnd != null) {
    status = TimerStatus.stopped;
  } else if (openBreaks.isNotEmpty) {
    status = TimerStatus.paused;
  } else {
    status = TimerStatus.running;
  }

  return TimerSnapshot(
    status: status,
    dayKey: entryDayKey(entry),
    workStartMs: start?.millisecondsSinceEpoch,
    pauseStartMs: status == TimerStatus.paused
        ? openBreaks.last.start.millisecondsSinceEpoch
        : null,
    netMinutes: net.isNegative ? 0 : net.inMinutes,
    targetMinutes:
        target == null || target.isNegative ? null : target.inMinutes,
    breakMinutes: entry.breaks
        .where((b) => b.end != null)
        .fold<int>(0, (sum, b) => sum + b.end!.difference(b.start).inMinutes),
    // Auf die Minute gerundet: der Wert wandert sonst jede Sekunde mit und
    // loest bei jedem Tick einen Widget-Write aus.
    expectedEndMs: expectedEnd == null
        ? null
        : expectedEnd.millisecondsSinceEpoch -
            expectedEnd.millisecondsSinceEpoch % Duration.millisecondsPerMinute,
    workEndMs: status == TimerStatus.stopped
        ? entry.workEnd?.millisecondsSinceEpoch
        : null,
    // Abrunden (nicht `inMinutes`, das zur Null kuerzt): ein negativer Saldo
    // wechselt so wie das Netto zur vollen Minute und nicht schon nach einer
    // Sekunde.
    overtimeMinutes: totalOvertime == null
        ? null
        : (totalOvertime.inSeconds / Duration.secondsPerMinute).floor(),
  );
}
