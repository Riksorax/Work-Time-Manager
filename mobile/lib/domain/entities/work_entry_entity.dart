import 'package:equatable/equatable.dart';

import 'break_entity.dart';

enum WorkEntryType {
  work,
  vacation,
  sick,
  holiday,
}

/// Die WorkEntryEntity ist ein reines Datenobjekt der Domain-Schicht.
/// Sie repräsentiert alle Informationen für einen einzelnen Arbeitstag.
class WorkEntryEntity extends Equatable {
  final String id;
  final DateTime date;
  final DateTime? workStart;
  final DateTime? workEnd;
  final List<BreakEntity> breaks;
  final Duration? manualOvertime;
  final bool isManuallyEntered;
  final String? description; // Added
  final WorkEntryType type;

  /// Home-Office-Tag (#277). Nur bei [WorkEntryType.work] relevant; fehlt das
  /// Feld in gespeicherten Daten, gilt `false`.
  final bool isHomeOffice;

  const WorkEntryEntity({
    required this.id,
    required this.date,
    this.workStart,
    this.workEnd,
    this.breaks = const [],
    this.manualOvertime,
    this.isManuallyEntered = false,
    this.description, // Added
    this.type = WorkEntryType.work,
    this.isHomeOffice = false,
  });

  /// Die gesamte Pausenzeit für diesen Arbeitseintrag.
  Duration get totalBreakTime {
    return breaks.fold(
        Duration.zero, (total, current) => total + current.duration);
  }

  /// Die gesamte Brutto-Arbeitszeit (ohne Pausen).
  Duration get totalWorkTime {
    if (workStart == null || workEnd == null) {
      return Duration.zero;
    }
    return workEnd!.difference(workStart!);
  }

  /// Die effektive Arbeitszeit (Brutto-Arbeitszeit abzüglich der Pausen).
  Duration get effectiveWorkDuration {
    return totalWorkTime - totalBreakTime;
  }

  /// Eine copyWith-Methode zur einfachen Erstellung einer neuen, modifizierten Instanz.
  /// Dies ist ein Kernprinzip der unveränderlichen (immutable) Zustandsverwaltung.
  ///
  /// Sie nimmt optionale Parameter entgegen. Wenn ein Parameter übergeben wird,
  /// wird dessen Wert für die neue Instanz verwendet. Andernfalls wird der
  /// Wert der aktuellen Instanz (this) beibehalten.
  WorkEntryEntity copyWith({
    String? id,
    DateTime? date,
    DateTime? workStart,
    DateTime? workEnd,
    List<BreakEntity>? breaks,
    Duration? manualOvertime,
    bool? isManuallyEntered,
    String? description, // Added
    WorkEntryType? type,
    bool? isHomeOffice,
  }) {
    return WorkEntryEntity(
      id: id ?? this.id,
      date: date ?? this.date,
      workStart: workStart ?? this.workStart,
      workEnd: workEnd ?? this.workEnd,
      breaks: breaks ?? this.breaks,
      manualOvertime: manualOvertime ?? this.manualOvertime,
      isManuallyEntered: isManuallyEntered ?? this.isManuallyEntered,
      description: description ?? this.description, // Added
      type: type ?? this.type,
      isHomeOffice: isHomeOffice ?? this.isHomeOffice,
    );
  }

  @override
  List<Object?> get props => [
        id,
        date,
        workStart,
        workEnd,
        breaks,
        manualOvertime,
        isManuallyEntered,
        description, // Added
        type,
        isHomeOffice,
      ];
}
