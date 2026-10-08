import 'package:flutter_work_time/core/utils/logger.dart';
import 'package:flutter_work_time/core/utils/time_precision.dart';

import '../entities/work_entry_entity.dart';
import '../repositories/overtime_repository.dart';
import '../repositories/work_repository.dart';
import '../services/break_calculator_service.dart';
import '../utils/overtime_utils.dart';

/// Ergebnis von [CloseOpenWorkEntry].
enum CloseOpenEntryResult {
  /// Eintrag und Saldo wurden geschrieben.
  closed,

  /// Der Eintrag ist im Repository nicht (mehr) offen oder nicht mehr
  /// vorhanden (anderes Gerät, Doppelklick); es wurde nichts geschrieben.
  alreadyClosed,

  /// Das Ende ist ungültig (nicht nach dem Start, nach jetzt oder vor dem
  /// Beginn der letzten Pause); es wurde nichts geschrieben.
  invalidEnd,

  /// Kein beendbarer Arbeitseintrag (Typ != work oder ohne Start).
  invalidEntry,

  /// Lesen oder Schreiben ist fehlgeschlagen. Der Eintrag bleibt offen.
  failed,
}

/// Beendet einen offenen Eintrag vor heute nachträglich (#385), ohne den
/// Dashboard-State anzufassen.
///
/// Ablauf: validieren, Eintrag frisch lesen, offene Pause schließen,
/// Auto-Pausen wie beim Stop, Saldo inkrementell fortschreiben
/// (`neu = alt + Netto - Soll am Eintragsdatum`), erst Saldo, dann Eintrag
/// speichern (wie im Stop-Pfad). Scheitert der Eintrag-Write nach dem Saldo,
/// wird der Saldo best-effort auf den gelesenen Stand zurückgeschrieben (#410,
/// Vorbild Web `OpenEntryCloseService`); scheitert auch das, bleibt er
/// verschoben und nur ein Log entsteht. Scheitert schon der Saldo-Write, gibt
/// es keinen Rollback. `lastUpdated` wird bewusst **nicht**
/// gesetzt: `DashboardViewModel._load` zieht bei `lastUpdated == heute` den
/// Tagesanteil des heutigen Eintrags vom Saldo ab. Eingeloggt setzt das
/// Backend es bei jedem Saldo-Write, daher `keepLastUpdated: true` (Backend ab
/// #408; eine ältere API ignoriert das Feld und setzt es weiterhin, #406).
///
/// Alle Zugriffe laufen über die Repositories des Konstruktors, also im
/// Profil, in dem der Use Case gebaut wurde.
class CloseOpenWorkEntry {
  final WorkRepository _workRepository;
  final OvertimeRepository _overtimeRepository;
  final DateTime Function() _clock;

  CloseOpenWorkEntry(this._workRepository, this._overtimeRepository,
      {DateTime Function() clock = DateTime.now})
      : _clock = clock;

  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  /// [dailyTarget] ist das Soll am Datum von [entry].
  Future<CloseOpenEntryResult> call({
    required WorkEntryEntity entry,
    required DateTime end,
    required Duration dailyTarget,
  }) async {
    if (entry.type != WorkEntryType.work || entry.workStart == null) {
      return CloseOpenEntryResult.invalidEntry;
    }
    final workEnd = roundToMinute(end);
    if (!_isValidEnd(entry, workEnd)) return CloseOpenEntryResult.invalidEnd;

    try {
      final fresh = await _readFresh(entry);
      if (fresh == null ||
          fresh.type != WorkEntryType.work ||
          fresh.workStart == null ||
          fresh.workEnd != null) {
        return CloseOpenEntryResult.alreadyClosed;
      }
      if (!_isValidEnd(fresh, workEnd)) return CloseOpenEntryResult.invalidEnd;

      var closed = fresh.copyWith(
        workEnd: workEnd,
        breaks: [
          for (final b in fresh.breaks)
            b.end == null ? b.copyWith(end: workEnd) : b,
        ],
      );
      closed = BreakCalculatorService.calculateAndApplyBreaks(closed);

      final net = workEnd.difference(closed.workStart!) - closed.totalBreakTime;
      final storedOvertime = await _overtimeRepository.ensureOvertimeLoaded();
      await _overtimeRepository.saveOvertime(storedOvertime + net - dailyTarget,
          keepLastUpdated: true);
      try {
        await _workRepository.saveWorkEntry(closed);
      } catch (_) {
        // Der Saldo ist schon verschoben, der Eintrag bleibt offen: ein
        // Wiederholen würde das Delta doppelt zählen. Best-effort zurück auf
        // den gelesenen Stand (#410); der Fehler des Eintrag-Writes geht an
        // den äußeren catch.
        await _rollbackOvertime(storedOvertime);
        rethrow;
      }
      return CloseOpenEntryResult.closed;
    } catch (e, st) {
      // Keine Eintragsinhalte loggen.
      logger.e(
          '[OpenEntries] Eintrag konnte nicht beendet werden '
          '(${e.runtimeType})',
          stackTrace: st);
      return CloseOpenEntryResult.failed;
    }
  }

  /// Schreibt den vor dem Vorwärts-Write gelesenen Saldo zurück. Mit
  /// `keepLastUpdated: true` stellt das den Vorzustand vollständig her. Ein
  /// Fehlschlag wird nur geloggt (keine Eintragsinhalte) und nie weitergeworfen;
  /// dann bleibt der Saldo verschoben (Korrektur über "Überstunden anpassen").
  Future<void> _rollbackOvertime(Duration stored) async {
    try {
      await _overtimeRepository.saveOvertime(stored, keepLastUpdated: true);
    } catch (e, st) {
      logger.e('[OpenEntries] Saldo-Rollback fehlgeschlagen (${e.runtimeType})',
          stackTrace: st);
    }
  }

  bool _isValidEnd(WorkEntryEntity entry, DateTime workEnd) =>
      isValidOpenEntryEnd(entry: entry, end: workEnd, now: _clock());

  Future<WorkEntryEntity?> _readFresh(WorkEntryEntity entry) async {
    final day = _dayOf(entry.date);
    final entries =
        await _workRepository.getWorkEntriesForMonth(day.year, day.month);
    for (final e in entries) {
      if (_dayOf(e.date) == day) return e;
    }
    return null;
  }
}
