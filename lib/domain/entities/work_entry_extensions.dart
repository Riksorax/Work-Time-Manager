import 'work_entry_entity.dart';

/// Diese Erweiterung fügt der WorkEntryEntity reine Berechnungslogik hinzu,
/// ohne die Entity-Klasse selbst zu "verschmutzen". Das hält die Entity als
/// reines Datenobjekt sauber.
extension WorkEntryCalculations on WorkEntryEntity {
  /// Berechnet die Brutto-Arbeitszeit (Zeit zwischen Start und Ende, ohne Pausen).
  /// Wenn der Timer noch läuft, wird die Zeit bis "jetzt" berechnet.
  Duration get calculatedWorkDuration {
    if (workStart == null) return Duration.zero;
    final end = workEnd ?? DateTime.now();
    return end.difference(workStart!);
  }

  /// Berechnet die Gesamtdauer aller abgeschlossenen Pausen.
  Duration get totalBreakDuration {
    if (breaks.isEmpty) return Duration.zero;
    return breaks.fold(
      Duration.zero,
          (total, currentBreak) => total + currentBreak.duration,
    );
  }

  /// Berechnet die effektive Arbeitszeit (Netto), also Brutto-Arbeitszeit minus Pausen.
  Duration get effectiveWorkDuration {
    final duration = calculatedWorkDuration - totalBreakDuration;
    return duration.isNegative ? Duration.zero : duration;
  }

  /// Berechnet die Über- oder Minusstunden für den Tag.
  ///
  /// [targetDailyHours] Die tägliche Soll-Arbeitszeit.
  Duration calculateOvertime(Duration targetDailyHours) {
    // Bei Sonder-Einträgen (Urlaub, Krank, Feiertag) gilt die Sollzeit als erfüllt.
    // Die Überstunden sind daher 0, es sei denn, es wurden manuelle Korrekturen vorgenommen.
    if (type == WorkEntryType.vacation || type == WorkEntryType.sick || type == WorkEntryType.holiday) {
      return manualOvertime ?? Duration.zero;
    }

    // Überstunden können erst berechnet werden, wenn der Arbeitstag abgeschlossen ist.
    if (workEnd == null) return Duration.zero;

    // Berücksichtige auch manuell hinzugefügte Überstunden.
    final totalOvertime = effectiveWorkDuration - targetDailyHours + (manualOvertime ?? Duration.zero);
    return totalOvertime;
  }
}