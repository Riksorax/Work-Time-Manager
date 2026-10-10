import '../../core/utils/time_precision.dart';
import '../entities/work_entry_entity.dart';
import 'entry_day.dart';

/// Reine Regeln für offene Einträge in den Reports (#404).
///
/// Offen heißt: Typ `work`, Start gesetzt, kein Ende. Das Backend
/// (`ReportCalculator`) zählt solche Einträge mit Netto 0. Mobile rechnet nur
/// den **heute** laufenden Eintrag live bis "jetzt"; ein offener Eintrag vor
/// heute (z. B. verwaister Vortag, #385) zählt 0.
///
/// Der Tag des Eintrags ist der lokale Kalendertag von [WorkEntryEntity.date]
/// (nie über UTC), "heute" der lokale Kalendertag von `now`. Der Aufrufer
/// übergibt die Uhr (`clockProvider`), die Funktionen kennen keine eigene.

bool _isOpenWorkEntry(WorkEntryEntity e) =>
    e.type == WorkEntryType.work && e.workStart != null && e.workEnd == null;

DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// `true`, wenn [e] offen ist und sein Tag vor dem Tag von [now] liegt.
bool isOpenBeforeToday(WorkEntryEntity e, DateTime now) =>
    _isOpenWorkEntry(e) && entryDay(e).isBefore(_dayOf(now));

/// Netto-Arbeitszeit eines Eintrags für die Reports-Anzeige.
///
/// - abgeschlossen: Ende - Start - Pausen (Pausen auf [Start, Ende] geklemmt)
/// - offen und Eintragstag == heute: live bis [now] (auf Minuten abgeschnitten,
///   offene Pause läuft bis dahin), nie negativ
/// - sonst offen: [Duration.zero]
Duration reportNetDuration(WorkEntryEntity e, {required DateTime now}) {
  final start = e.workStart;
  if (start == null) return Duration.zero;

  DateTime end;
  final workEnd = e.workEnd;
  if (workEnd != null) {
    end = workEnd;
  } else {
    final isLive = _isOpenWorkEntry(e) && entryDay(e) == _dayOf(now);
    if (!isLive) return Duration.zero;
    final nowMinute = roundToMinute(now);
    end = nowMinute.isBefore(start) ? start : nowMinute;
  }

  var breakDuration = Duration.zero;
  for (final b in e.breaks) {
    final bEnd = b.end ?? end;
    final effStart = b.start.isBefore(start) ? start : b.start;
    final effEnd = bEnd.isAfter(end) ? end : bEnd;
    if (effEnd.isAfter(effStart)) {
      breakDuration += effEnd.difference(effStart);
    }
  }
  return end.difference(start) - breakDuration;
}
