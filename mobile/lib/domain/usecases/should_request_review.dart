import 'package:flutter_work_time/core/utils/logger.dart';

import '../entities/work_entry_entity.dart';
import '../repositories/review_prompt_repository.dart';
import '../repositories/work_repository.dart';
import '../utils/entry_day.dart';

/// Schwellenwerte der einmaligen Bewertungsanfrage (an einer Stelle).
class ReviewPromptThresholds {
  const ReviewPromptThresholds._();

  /// Mindestanzahl Kalendertage seit der Erstnutzung.
  static const minDaysSinceFirstUse = 7;

  /// Mindestanzahl Arbeitstage mit abgeschlossenem Eintrag (Typ `work`, Start
  /// und Ende gesetzt).
  static const minCompletedWorkDays = 5;

  /// Wie viele Monate (inkl. aktuellem) maximal nach abgeschlossenen
  /// Arbeitstagen durchsucht werden.
  static const maxMonthsToScan = 12;
}

/// Entscheidet, ob jetzt die einmalige Bewertungsanfrage fällig ist.
///
/// Alle Bedingungen müssen erfüllt sein: noch nie angefragt, kein laufender
/// Timer, Erstnutzung mindestens [ReviewPromptThresholds.minDaysSinceFirstUse]
/// Tage her und mindestens [ReviewPromptThresholds.minCompletedWorkDays]
/// abgeschlossene Arbeitstage. Die Arbeitstage kommen aus dem
/// [WorkRepository] (Hybrid-Layer, aktives Profil), nicht aus einem eigenen
/// Zähler. Das Datum kommt ausschließlich über die injizierte Uhr.
class ShouldRequestReviewUseCase {
  final ReviewPromptRepository _promptRepository;
  final WorkRepository _workRepository;
  final DateTime Function() _clock;

  ShouldRequestReviewUseCase(
    this._promptRepository,
    this._workRepository, {
    DateTime Function() clock = DateTime.now,
  }) : _clock = clock;

  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  /// `true`, wenn die Anfrage jetzt ausgelöst werden soll. Wirft nie: bei
  /// einem Lesefehler gilt "nicht fällig".
  Future<bool> call({required bool isTimerRunning}) async {
    if (isTimerRunning) return false;
    try {
      if (_promptRepository.wasPrompted()) return false;

      final today = _dayOf(_clock());
      final firstUse = _promptRepository.getFirstUseDate();
      if (firstUse == null) {
        // Noch nicht erfasst: ab jetzt zählen, nicht rückwirkend anfragen.
        await _promptRepository.saveFirstUseDateIfAbsent(today);
        return false;
      }
      if (_daysBetween(firstUse, today) <
          ReviewPromptThresholds.minDaysSinceFirstUse) {
        return false;
      }

      return await _hasEnoughCompletedWorkDays(today);
    } catch (e, st) {
      logger.e('[Review] Prüfung fehlgeschlagen (${e.runtimeType})',
          stackTrace: st);
      return false;
    }
  }

  /// Merkt sich, dass die Anfrage ausgelöst wird. Vor dem eigentlichen Aufruf
  /// zu verwenden: Google begrenzt die Anzeige, ein Aufruf garantiert sie
  /// nicht, und es soll nie eine zweite Anfrage geben.
  Future<void> markRequested() => _promptRepository.markPrompted();

  /// Kalendertage zwischen zwei lokalen Tagen, unabhängig von
  /// Sommerzeitwechseln (Vergleich über UTC-Mitternachten).
  static int _daysBetween(DateTime from, DateTime to) =>
      DateTime.utc(to.year, to.month, to.day)
          .difference(DateTime.utc(from.year, from.month, from.day))
          .inDays;

  Future<bool> _hasEnoughCompletedWorkDays(DateTime today) async {
    final days = <DateTime>{};
    for (var i = 0; i < ReviewPromptThresholds.maxMonthsToScan; i++) {
      // DateTime normalisiert Monat <= 0 auf das Vorjahr.
      final month = DateTime(today.year, today.month - i);
      final entries =
          await _workRepository.getWorkEntriesForMonth(month.year, month.month);
      for (final e in entries) {
        if (e.type == WorkEntryType.work &&
            e.workStart != null &&
            e.workEnd != null) {
          days.add(entryDay(e));
        }
      }
      if (days.length >= ReviewPromptThresholds.minCompletedWorkDays) {
        return true;
      }
    }
    return false;
  }
}
