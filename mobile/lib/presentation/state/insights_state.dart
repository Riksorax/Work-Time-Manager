import 'package:equatable/equatable.dart';

import '../../domain/utils/insights_utils.dart';

/// Zustand für die Arbeitszeit-Insights (siehe #134): Wochentags-Analyse,
/// Burnout-Indikator und Produktivitäts-Heatmap über mehrere Monate.
class InsightsState extends Equatable {
  final bool isLoading;
  final List<WeekdayAverage> weekdayAverages;
  final BurnoutStatus burnoutStatus;
  final List<StartTimeBucket> heatmap;

  const InsightsState({
    this.isLoading = false,
    required this.weekdayAverages,
    required this.burnoutStatus,
    required this.heatmap,
  });

  factory InsightsState.initial() => const InsightsState(
        isLoading: true,
        weekdayAverages: [],
        burnoutStatus: BurnoutStatus(currentStreak: 0, longestStreak: 0, isWarning: false),
        heatmap: [],
      );

  /// `true`, wenn nach dem Laden zu wenig Datenbasis für Insights vorhanden
  /// ist (z.B. neuer Nutzer ohne Historie).
  bool get hasNoData => !isLoading && weekdayAverages.isEmpty && heatmap.isEmpty;

  InsightsState copyWith({
    bool? isLoading,
    List<WeekdayAverage>? weekdayAverages,
    BurnoutStatus? burnoutStatus,
    List<StartTimeBucket>? heatmap,
  }) {
    return InsightsState(
      isLoading: isLoading ?? this.isLoading,
      weekdayAverages: weekdayAverages ?? this.weekdayAverages,
      burnoutStatus: burnoutStatus ?? this.burnoutStatus,
      heatmap: heatmap ?? this.heatmap,
    );
  }

  @override
  List<Object?> get props => [isLoading, weekdayAverages, burnoutStatus, heatmap];
}
