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

  const TimerSnapshot({
    required this.status,
    required this.dayKey,
    this.workStartMs,
    this.pauseStartMs,
    this.netMinutes = 0,
  });

  @override
  List<Object?> get props =>
      [status, dayKey, workStartMs, pauseStartMs, netMinutes];
}

/// Baut den Snapshot aus [entry] und der bereits berechneten Netto-Dauer [net].
///
/// Status: kein Start -> `notStarted`; Ende gesetzt -> `stopped`; offene Pause
/// -> `paused`; sonst `running`.
TimerSnapshot buildTimerSnapshot({
  required WorkEntryEntity entry,
  required Duration net,
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
  );
}
