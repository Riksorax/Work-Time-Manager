import '../entities/work_entry_entity.dart';
import '../repositories/work_repository.dart';

/// Use Case, der die Logik zum Starten oder Stoppen des Haupt-Timers kapselt.
class StartOrStopTimer {
  final WorkRepository _repository;

  StartOrStopTimer(this._repository);

  /// Führt die Logik aus und gibt die aktualisierte Entity zurück.
  /// Nimmt die aktuelle Entity als Parameter, um den Zustand zu ändern.
  Future<WorkEntryEntity> call(WorkEntryEntity currentEntry) async {
    final WorkEntryEntity updatedEntry;

    if (currentEntry.workStart == null) {
      // Fall 1: Timer wurde noch nicht gestartet. -> STARTEN
      updatedEntry = currentEntry.copyWith(workStart: DateTime.now());
    } else if (currentEntry.workEnd == null) {
      // Fall 2: Timer läuft, aber wurde noch nicht gestoppt. -> STOPPEN
      updatedEntry = currentEntry.copyWith(workEnd: DateTime.now());
    } else {
      // Fall 3: Timer wurde bereits gestoppt. Nichts tun.
      return currentEntry;
    }

    // Den neuen Zustand speichern.
    await _repository.saveWorkEntry(updatedEntry);

    // Den neuen Zustand an das ViewModel zurückgeben, damit die UI sich aktualisieren kann.
    return updatedEntry;
  }
}

// HINWEIS: Für diesen Code muss deine `WorkEntryEntity` eine `copyWith`-Methode haben.
// Füge sie zu `work_entry_entity.dart` hinzu, wenn sie noch nicht existiert:
/*
  WorkEntryEntity copyWith({
    String? id,
    DateTime? date,
    DateTime? workStart,
    DateTime? workEnd,
    List<BreakEntity>? breaks,
    Duration? manualOvertime,
  }) {
    return WorkEntryEntity(
      id: id ?? this.id,
      date: date ?? this.date,
      workStart: workStart ?? this.workStart,
      workEnd: workEnd ?? this.workEnd,
      breaks: breaks ?? this.breaks,
      manualOvertime: manualOvertime ?? this.manualOvertime,
    );
  }
*/