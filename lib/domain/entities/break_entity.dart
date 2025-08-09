import 'package:equatable/equatable.dart';

class BreakEntity extends Equatable {
  final String id;
  final String name;
  final DateTime start;
  final DateTime? end;

  const BreakEntity({required this.id, required this.name, required this.start, this.end});

  /// Calculates the duration of the break.
  /// Returns [Duration.zero] if the break hasn't ended yet.
  Duration get duration {
    if (end != null) {
      return end!.difference(start);
    }
    return Duration.zero;
  }

  BreakEntity copyWith({
    String? id,
    String? name,
    DateTime? start,
    DateTime? end,
  }) {
    return BreakEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }

  @override
  List<Object?> get props => [id, name, start, end];
}
