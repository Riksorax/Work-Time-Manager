import 'package:equatable/equatable.dart';

import '../../domain/entities/weekly_reflection_entity.dart';

/// Zustand für die Wochen-Reflexion (siehe #137).
class WeeklyReflectionState extends Equatable {
  final bool isLoading;
  final bool isSaving;
  final WeeklyReflectionEntity? reflection;

  const WeeklyReflectionState({
    this.isLoading = false,
    this.isSaving = false,
    this.reflection,
  });

  factory WeeklyReflectionState.initial() =>
      const WeeklyReflectionState(isLoading: true);

  WeeklyReflectionState copyWith({
    bool? isLoading,
    bool? isSaving,
    WeeklyReflectionEntity? reflection,
  }) {
    return WeeklyReflectionState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      reflection: reflection ?? this.reflection,
    );
  }

  @override
  List<Object?> get props => [isLoading, isSaving, reflection];
}
