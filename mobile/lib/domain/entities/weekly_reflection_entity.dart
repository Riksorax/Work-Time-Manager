import 'package:equatable/equatable.dart';

/// Eine Wochen-Reflexion (siehe #137): kurzer strukturierter Rückblick auf
/// eine Kalenderwoche - was lief gut, was war anstrengend.
class WeeklyReflectionEntity extends Equatable {
  final int year;
  final int week;
  final String whatWentWell;
  final String whatWasHard;
  final DateTime? updatedAt;

  const WeeklyReflectionEntity({
    required this.year,
    required this.week,
    this.whatWentWell = '',
    this.whatWasHard = '',
    this.updatedAt,
  });

  /// Eindeutiger Dokument-Schlüssel im Format `yyyy-Www`, z.B. `2026-W11`.
  String get id => '$year-W${week.toString().padLeft(2, '0')}';

  bool get isEmpty => whatWentWell.trim().isEmpty && whatWasHard.trim().isEmpty;

  WeeklyReflectionEntity copyWith({
    String? whatWentWell,
    String? whatWasHard,
    DateTime? updatedAt,
  }) {
    return WeeklyReflectionEntity(
      year: year,
      week: week,
      whatWentWell: whatWentWell ?? this.whatWentWell,
      whatWasHard: whatWasHard ?? this.whatWasHard,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [year, week, whatWentWell, whatWasHard, updatedAt];
}
