import 'package:collection/collection.dart';
import 'package:uuid/uuid.dart';

import 'package:flutter_work_time/core/utils/time_precision.dart';

import '../entities/break_entity.dart';
import '../entities/work_entry_entity.dart';
import '../repositories/work_repository.dart';

/// Use Case, um eine Pause zu starten oder die aktuell laufende zu beenden.
class ToggleBreak {
  final WorkRepository _repository;

  ToggleBreak(this._repository);

  /// Führt den Use Case aus.
  /// Nimmt den aktuellen Arbeitseintrag und gibt den modifizierten zurück.
  Future<WorkEntryEntity> call(WorkEntryEntity currentEntry) async {
    // Finde eine laufende Pause (eine ohne Endzeit).
    final activeBreak = currentEntry.breaks.firstWhereOrNull(
          (b) => b.end == null,
    );

    WorkEntryEntity updatedEntry;

    if (activeBreak != null) {
      // --- Fall 1: Eine Pause ist aktiv -> Beende sie ---
      final updatedBreaks = currentEntry.breaks.map((b) {
        if (b == activeBreak) {
          // Erstelle eine neue Instanz der Pause mit gesetzter Endzeit.
          return b.copyWith(end: nowToMinute());
        }
        return b;
      }).toList();

      updatedEntry = currentEntry.copyWith(breaks: updatedBreaks);
    } else {
      // --- Fall 2: Keine Pause ist aktiv -> Starte eine neue ---
      final newBreak = BreakEntity(
        id: const Uuid().v4(),
        name: 'Pause ${currentEntry.breaks.length + 1}',
        start: nowToMinute(),
      );

      // Füge die neue Pause zur Liste der Pausen hinzu.
      updatedEntry = currentEntry.copyWith(
        breaks: [...currentEntry.breaks, newBreak],
      );
    }

    // Speichere den aktualisierten Arbeitseintrag in der Datenbank.
    await _repository.saveWorkEntry(updatedEntry);

    // Gib den aktualisierten Eintrag zurück, damit das ViewModel seinen Zustand erneuern kann.
    return updatedEntry;
  }
}