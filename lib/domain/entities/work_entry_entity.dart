import 'package:equatable/equatable.dart';

import 'break_entity.dart';

/// Die WorkEntryEntity ist ein reines Datenobjekt der Domain-Schicht.
/// Sie repräsentiert alle Informationen für einen einzelnen Arbeitstag.
class WorkEntryEntity extends Equatable {
  final String id;
  final DateTime date;
  final DateTime? workStart;
  final DateTime? workEnd;
  final List<BreakEntity> breaks;
  final Duration? manualOvertime;

  const WorkEntryEntity({
    required this.id,
    required this.date,
    this.workStart,
    this.workEnd,
    this.breaks = const [],
    this.manualOvertime,
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

  @override
  List<Object?> get props => [
        id,
        date,
        workStart,
        workEnd,
        breaks,
        manualOvertime,
      ];
}