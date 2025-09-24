import 'package:uuid/uuid.dart';
import '../entities/break_entity.dart';
import '../entities/work_entry_entity.dart';

class BreakCalculatorService {
  static const Duration minWorkTimeForFirstBreak = Duration(hours: 6);
  static const Duration minWorkTimeForSecondBreak = Duration(hours: 9);
  static const Duration firstBreakDuration = Duration(minutes: 30); // Gesetzlich vorgeschriebene Pausenzeit bei 6+ Stunden
  static const Duration secondBreakDuration = Duration(minutes: 15);
  static const Duration requiredBreakTimeForLongDay = Duration(minutes: 45); // Gesetzlich vorgeschriebene Pausenzeit bei 9+ Stunden

  /// Berechnet die automatischen Pausen basierend auf der Arbeitszeit
  /// und gibt einen aktualisierten WorkEntryEntity zurück.
  static WorkEntryEntity calculateAndApplyBreaks(WorkEntryEntity entry) {
    if (entry.workStart == null || entry.workEnd == null) {
      return entry; // Keine Berechnung möglich ohne Start- und Endzeit
    }

    final totalWorkTime = entry.totalWorkTime;
    final existingBreaks = entry.breaks;

    // Überprüfe, ob wir die gesetzlichen Mindestpausen einhalten müssen
    bool needsFirstBreak = totalWorkTime >= minWorkTimeForFirstBreak;
    bool needsSecondBreak = totalWorkTime >= minWorkTimeForSecondBreak;

    // Wenn keine Pausen vorhanden sind, füge automatische Pausen hinzu
    if (existingBreaks.isEmpty) {
      final calculatedBreaks = _calculateBreaks(entry.workStart!, entry.workEnd!, totalWorkTime);
      return entry.copyWith(breaks: calculatedBreaks);
    } else {
      // Wenn Pausen vorhanden sind, passe sie an das Schema an
      final adjustedBreaks = _adjustExistingBreaks(entry.workStart!, entry.workEnd!, totalWorkTime, existingBreaks);
      return entry.copyWith(breaks: adjustedBreaks);
    }
  }

  static List<BreakEntity> _calculateBreaks(DateTime workStart, DateTime workEnd, Duration totalWorkTime) {
    final List<BreakEntity> breaks = [];
    final uuid = Uuid();

    // Bei einer Arbeitszeit von 9+ Stunden muss die Gesamtpausenzeit 45 Minuten betragen
    if (totalWorkTime >= minWorkTimeForSecondBreak) {
      final breakStart = workStart.add(Duration(hours: 4)); // Hauptpause nach 4 Stunden
      final breakEnd = breakStart.add(const Duration(minutes: 30)); // 30 Minuten Pause

      // Prüfe, ob die Pause nicht nach Arbeitsende liegt
      if (breakEnd.isBefore(workEnd)) {
        breaks.add(BreakEntity(
          id: uuid.v4(),
          name: 'Mittagspause',
          start: breakStart,
          end: breakEnd,
          isAutomatic: true,
        ));

        // Zweite Pause für die restlichen 15 Minuten
        final secondBreakStart = breakEnd.add(Duration(hours: 2)); // 2 Stunden nach der ersten Pause
        final secondBreakEnd = secondBreakStart.add(const Duration(minutes: 15));

        if (secondBreakEnd.isBefore(workEnd)) {
          breaks.add(BreakEntity(
            id: uuid.v4(),
            name: 'Kurzpause',
            start: secondBreakStart,
            end: secondBreakEnd,
            isAutomatic: true,
          ));
        }
      }
    }
    // Füge Pause hinzu wenn Arbeitszeit zwischen 6 und 9 Stunden liegt
    else if (totalWorkTime >= minWorkTimeForFirstBreak) {
      final breakStart = workStart.add(Duration(hours: 4)); // Pause nach 4 Stunden
      final breakEnd = breakStart.add(firstBreakDuration);

      // Prüfe, ob die Pause nicht nach Arbeitsende liegt
      if (breakEnd.isBefore(workEnd)) {
        breaks.add(BreakEntity(
          id: uuid.v4(),
          name: 'Mittagspause',
          start: breakStart,
          end: breakEnd,
        ));
      }
    }

    return breaks;
  }

  static List<BreakEntity> _adjustExistingBreaks(DateTime workStart, DateTime workEnd, Duration totalWorkTime, List<BreakEntity> existingBreaks) {
    // Berechne die erforderliche Gesamtpausenzeit basierend auf der Arbeitszeit
    Duration requiredBreakTime = Duration.zero;
    bool needsSecondBreak = false;

    if (totalWorkTime >= minWorkTimeForSecondBreak) {
      // Bei 9+ Stunden ist eine Gesamtpausenzeit von genau 45 Minuten erforderlich
      requiredBreakTime = requiredBreakTimeForLongDay;
      needsSecondBreak = true;
    } else if (totalWorkTime >= minWorkTimeForFirstBreak) {
      // Bei 6+ Stunden ist eine Gesamtpausenzeit von genau 30 Minuten erforderlich
      requiredBreakTime = firstBreakDuration;
    }

    // Berechne die tatsächliche Gesamtpausenzeit
    final Duration actualBreakTime = existingBreaks.fold(
      Duration.zero, 
      (total, breakEntity) => total + breakEntity.duration
    );

    // Wenn die tatsächliche Pausenzeit bereits ausreicht
    // Für 9+ Std: mindestens 45 Min gesamt, idealerweise auf 2 Pausen verteilt
    // Für 6-9 Std: genau 30 Min
    if (actualBreakTime >= requiredBreakTime && 
        ((totalWorkTime >= minWorkTimeForSecondBreak && (existingBreaks.length >= 2 || !needsSecondBreak)) ||
         (totalWorkTime >= minWorkTimeForFirstBreak && totalWorkTime < minWorkTimeForSecondBreak))) {
      return existingBreaks;
    }

    // Bei einer Arbeitszeit von 9+ Stunden und vorhandenen Pausen
    if (totalWorkTime >= minWorkTimeForSecondBreak) {
      final uuid = Uuid();
      List<BreakEntity> adjustedBreaks = List.from(existingBreaks);

      // Berechne die aktuelle Gesamtpausenzeit
      final Duration actualBreakTime = existingBreaks.fold(
        Duration.zero, 
        (total, breakEntity) => total + breakEntity.duration
      );

      // Wenn die Gesamtpause bereits 45 Minuten beträgt oder länger ist, keine Änderung nötig
      if (actualBreakTime >= requiredBreakTimeForLongDay) {
        return existingBreaks;
      }

      // Berechne die fehlende Pausenzeit, um genau 45 Minuten zu erreichen
      final Duration missingBreakTime = requiredBreakTimeForLongDay - actualBreakTime;

      // Füge eine neue automatische Pause für die fehlende Zeit hinzu
      if (missingBreakTime > Duration.zero) {
        // Bestimme eine gute Position für die automatische Pause
        DateTime autoBreakStart;

        if (existingBreaks.isNotEmpty && existingBreaks.last.end != null) {
          // Setze die automatische Pause nach der letzten vorhandenen Pause
          autoBreakStart = existingBreaks.last.end!.add(Duration(hours: 1));
        } else {
          // Wenn keine beendeten Pausen vorhanden sind, setze sie etwa in die Mitte der Arbeitszeit
          autoBreakStart = workStart.add(totalWorkTime ~/ 2);
        }

        // Stelle sicher, dass die automatische Pause vor dem Arbeitsende liegt
        if (autoBreakStart.add(missingBreakTime).isBefore(workEnd)) {
          adjustedBreaks.add(BreakEntity(
            id: uuid.v4(),
            name: 'Automatische Pause',
            start: autoBreakStart,
            end: autoBreakStart.add(missingBreakTime),
            isAutomatic: true,
          ));

          return adjustedBreaks;
        }
      }
    }

    // Für Arbeitszeit unter 9 Stunden
    final uuid = Uuid();
    List<BreakEntity> adjustedBreaks = List.from(existingBreaks);
    final additionalTime = requiredBreakTime - actualBreakTime;

    // Für Arbeitszeiten zwischen 6-9 Stunden: genau 30 Minuten Pause
    if (totalWorkTime >= minWorkTimeForFirstBreak && 
        totalWorkTime < minWorkTimeForSecondBreak) {

      // Wenn die tatsächliche Pausenzeit bereits genau 30 Minuten beträgt, keine Änderung nötig
      if (actualBreakTime == firstBreakDuration) {
        return existingBreaks;
      }

      // Falls existierende Pausen vorhanden sind, aber die Gesamtzeit nicht exakt 30 Minuten ist
      if (existingBreaks.isNotEmpty) {
        // Wenn die Gesamtpausenzeit zu kurz ist, verlängere die letzte Pause
        if (actualBreakTime < firstBreakDuration) {
          final lastBreak = existingBreaks.last;

          // Verlängere die letzte Pause, wenn sie einen Endpunkt hat
          if (lastBreak.end != null) {
            final newEnd = lastBreak.end!.add(additionalTime);
            if (newEnd.isBefore(workEnd)) {
              final adjustedBreak = lastBreak.copyWith(end: newEnd);
              adjustedBreaks[adjustedBreaks.length - 1] = adjustedBreak;
              return adjustedBreaks;
            }
          }
        }
        // Wenn die Gesamtpausenzeit zu lang ist, kürze oder entferne Pausen
        else if (actualBreakTime > firstBreakDuration) {
          // Hier könnten wir Pausen kürzen, um genau 30 Minuten zu erreichen
          // Für jetzt belassen wir die bestehenden Pausen
          return existingBreaks;
        }
      }

      // Wenn keine Pause verlängert werden konnte, füge eine neue hinzu
      final breakStart = workStart.add(Duration(hours: 4)); // Pause typischerweise nach 4 Stunden
      final breakEnd = breakStart.add(firstBreakDuration);

      if (breakEnd.isBefore(workEnd)) {
        adjustedBreaks.add(BreakEntity(
          id: uuid.v4(),
          name: 'Automatische Pause',
          start: breakStart,
          end: breakEnd,
          isAutomatic: true,
        ));
      }
    }

    return adjustedBreaks;
  }
}
