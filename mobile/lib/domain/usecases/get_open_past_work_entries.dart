import 'package:flutter_work_time/core/utils/api_errors.dart';
import 'package:flutter_work_time/core/utils/logger.dart';

import '../entities/work_entry_entity.dart';
import '../repositories/work_repository.dart';
import '../utils/entry_day.dart';

/// Findet offene Arbeitseinträge vor heute (#385): `workStart != null`,
/// `workEnd == null`, Typ `work`, Kalendertag vor heute.
///
/// Gelesen werden der aktuelle und der Vormonat des aktiven Profils (das
/// übergebene Repository ist profilgebunden). Ältere Einträge werden bewusst
/// nicht gesucht.
class GetOpenPastWorkEntries {
  final WorkRepository _repository;
  final DateTime Function() _clock;

  GetOpenPastWorkEntries(this._repository,
      {DateTime Function() clock = DateTime.now})
      : _clock = clock;

  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Offene Einträge, neuester zuerst. [excludeDate] (Kalendertag) nimmt den
  /// im Dashboard laufenden Eintrag aus.
  Future<List<WorkEntryEntity>> call({DateTime? excludeDate}) async {
    final today = _dayOf(_clock());
    final excluded = excludeDate == null ? null : _dayOf(excludeDate);
    // DateTime normalisiert Monat 0 auf Dezember des Vorjahres.
    final previousMonth = DateTime(today.year, today.month - 1);

    final result = <WorkEntryEntity>[];
    for (final month in [today, previousMonth]) {
      try {
        final entries =
            await _repository.getWorkEntriesForMonth(month.year, month.month);
        result.addAll(entries.where((e) {
          final day = entryDay(e);
          return e.type == WorkEntryType.work &&
              e.workStart != null &&
              e.workEnd == null &&
              day.isBefore(today) &&
              day != excluded;
        }));
      } catch (e, st) {
        // Keine Eintragsinhalte loggen.
        if (isExpectedLoadFailure(e)) {
          // Offline oder gerade abgemeldet: kein App-Fehler (#506, #522).
          logger.i('[OpenEntries] Monat nicht geladen (${errorLabel(e)})');
        } else {
          logger.e(
              '[OpenEntries] Monat konnte nicht gelesen werden '
              '(${errorLabel(e)})',
              stackTrace: st);
        }
      }
    }
    result.sort((a, b) => entryDay(b).compareTo(entryDay(a)));
    return result;
  }
}
