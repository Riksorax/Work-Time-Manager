import 'package:uuid/uuid.dart';
import 'package:flutter_work_time/core/utils/logger.dart';
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
  ///
  /// WICHTIG: Diese Funktion behält ALLE manuellen Pausen (isAutomatic: false)
  /// und passt nur automatische Pausen an.
  static WorkEntryEntity calculateAndApplyBreaks(WorkEntryEntity entry) {
    if (entry.workStart == null || entry.workEnd == null) {
      return entry; // Keine Berechnung möglich ohne Start- und Endzeit
    }

    final totalWorkTime = entry.totalWorkTime;
    final existingBreaks = entry.breaks;

    // Trenne manuelle und automatische Pausen
    final manualBreaks = existingBreaks.where((b) => !b.isAutomatic).toList();
    final automaticBreaks = existingBreaks.where((b) => b.isAutomatic).toList();

    logger.i('[BreakCalculator] Bestehende Pausen: ${existingBreaks.length} (${manualBreaks.length} manuell, ${automaticBreaks.length} automatisch)');

    // Wenn keine Pausen vorhanden sind, füge automatische Pausen hinzu
    if (existingBreaks.isEmpty) {
      final calculatedBreaks = _calculateBreaks(entry.workStart!, entry.workEnd!, totalWorkTime);
      logger.i('[BreakCalculator] Keine Pausen vorhanden, füge ${calculatedBreaks.length} automatische hinzu');
      return entry.copyWith(breaks: calculatedBreaks);
    } else {
      // Wenn Pausen vorhanden sind, behalte manuelle und passe nur automatische an
      final adjustedAutoBreaks = _adjustExistingBreaks(entry.workStart!, entry.workEnd!, totalWorkTime, existingBreaks);
      logger.i('[BreakCalculator] Pausen angepasst: ${adjustedAutoBreaks.length} gesamt');
      return entry.copyWith(breaks: adjustedAutoBreaks);
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
          isAutomatic: true,
        ));
      }
    }

    return breaks;
  }

  static List<BreakEntity> _adjustExistingBreaks(DateTime workStart, DateTime workEnd, Duration totalWorkTime, List<BreakEntity> existingBreaks) {
    // Trenne manuelle und automatische Pausen
    final manualBreaks = existingBreaks.where((b) => !b.isAutomatic).toList();

    // Berechne die erforderliche Gesamtpausenzeit basierend auf der Arbeitszeit
    Duration requiredBreakTime = Duration.zero;

    if (totalWorkTime >= minWorkTimeForSecondBreak) {
      // Bei 9+ Stunden ist eine Gesamtpausenzeit von genau 45 Minuten erforderlich
      requiredBreakTime = requiredBreakTimeForLongDay;
    } else if (totalWorkTime >= minWorkTimeForFirstBreak) {
      // Bei 6+ Stunden ist eine Gesamtpausenzeit von genau 30 Minuten erforderlich
      requiredBreakTime = firstBreakDuration;
    }

    // Berechne die tatsächliche Gesamtpausenzeit (manuell + automatisch)
    final Duration actualBreakTime = existingBreaks.fold(
      Duration.zero,
      (total, breakEntity) => total + breakEntity.duration
    );

    // Wenn die tatsächliche Pausenzeit bereits ausreicht, behalte alle Pausen
    if (actualBreakTime >= requiredBreakTime) {
      logger.i('[BreakCalculator] Pausenzeit ausreichend (${actualBreakTime.inMinutes} Min), behalte alle Pausen');
      return existingBreaks;
    }

    // WICHTIG: Manuelle Pausen IMMER behalten!
    // Nur automatische Pausen werden hinzugefügt, wenn nötig

    // Berechne fehlende Pausenzeit
    final Duration missingBreakTime = requiredBreakTime - actualBreakTime;

    // Wenn keine zusätzlichen Pausen nötig sind, behalte alle existierenden
    if (missingBreakTime <= Duration.zero) {
      logger.i('[BreakCalculator] Pausenzeit ausreichend, keine zusätzlichen Pausen nötig');
      return existingBreaks;
    }

    // Füge automatische Pause(n) hinzu, um die fehlende Zeit zu ergänzen
    final uuid = Uuid();
    final List<BreakEntity> result = List.from(manualBreaks); // Starte mit manuellen Pausen

    // Bestimme Position für die automatische Pause
    DateTime autoBreakStart;

    if (existingBreaks.isNotEmpty && existingBreaks.last.end != null) {
      // Setze die automatische Pause nach der letzten vorhandenen Pause
      autoBreakStart = existingBreaks.last.end!.add(const Duration(hours: 1));
    } else {
      // Setze sie etwa nach 4 Stunden Arbeit
      autoBreakStart = workStart.add(const Duration(hours: 4));
    }

    // Stelle sicher, dass die automatische Pause vor dem Arbeitsende liegt
    if (autoBreakStart.add(missingBreakTime).isBefore(workEnd)) {
      result.add(BreakEntity(
        id: uuid.v4(),
        name: 'Automatische Pause',
        start: autoBreakStart,
        end: autoBreakStart.add(missingBreakTime),
        isAutomatic: true,
      ));
      logger.i('[BreakCalculator] Füge ${missingBreakTime.inMinutes} Min automatische Pause hinzu (${manualBreaks.length} manuelle bleiben erhalten)');
    } else {
      logger.i('[BreakCalculator] Kann keine automatische Pause hinzufügen (würde nach Arbeitsende liegen)');
    }

    return result;
  }
}
