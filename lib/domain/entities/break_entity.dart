import 'package:equatable/equatable.dart';

/// Repräsentiert eine einzelne Pause während eines Arbeitstages.
class BreakEntity extends Equatable {
  /// Eine optionale Bezeichnung für die Pause (z.B. "Mittagspause").
  final String name;

  /// Der Zeitstempel, an dem die Pause begonnen hat.
  final DateTime start;

  /// Der Zeitstempel, an dem die Pause beendet wurde.
  /// Ist null, wenn die Pause noch läuft.
  final DateTime? end;

  const BreakEntity({
    required this.name,
    required this.start,
    this.end,
  });

  /// Berechnet die Dauer der Pause.
  /// Gibt Duration.zero zurück, wenn die Pause noch nicht beendet ist.
  Duration get duration => end != null ? end!.difference(start) : Duration.zero;

  @override
  List<Object?> get props => [name, start, end];

  /// Eine copyWith-Methode, um eine neue Instanz mit geänderten Werten
  /// zu erstellen. Dies ist nützlich für die unveränderliche Zustandsverwaltung.
  BreakEntity copyWith({
    String? name,
    DateTime? start,
    DateTime? end,
  }) {
    return BreakEntity(
      name: name ?? this.name,
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }
}