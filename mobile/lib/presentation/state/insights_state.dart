import 'package:equatable/equatable.dart';

import '../../domain/utils/insights_utils.dart';
import 'reports_state.dart' show ReportsLoadFailure;

/// Zustand für die Arbeitszeit-Insights (siehe #134): Wochentags-Analyse,
/// Burnout-Indikator und Produktivitäts-Heatmap über mehrere Monate.
class InsightsState extends Equatable {
  final bool isLoading;
  final List<WeekdayAverage> weekdayAverages;
  final BurnoutStatus burnoutStatus;
  final List<StartTimeBucket> heatmap;

  /// Die Insights ließen sich nicht laden (#537, wie die Berichte #573):
  /// `offline` bei Netzwerkfehler, `failed` sonst. Kein Offline-Ersatz.
  final ReportsLoadFailure loadFailure;

  const InsightsState({
    this.isLoading = false,
    required this.weekdayAverages,
    required this.burnoutStatus,
    required this.heatmap,
    this.loadFailure = ReportsLoadFailure.none,
  });

  factory InsightsState.initial() => const InsightsState(
        isLoading: true,
        weekdayAverages: [],
        burnoutStatus:
            BurnoutStatus(currentStreak: 0, longestStreak: 0, isWarning: false),
        heatmap: [],
      );

  /// `true`, wenn nach dem Laden zu wenig Datenbasis für Insights vorhanden
  /// ist (z.B. neuer Nutzer ohne Historie).
  bool get hasNoData =>
      !isLoading &&
      loadFailure == ReportsLoadFailure.none &&
      weekdayAverages.isEmpty &&
      heatmap.isEmpty;

  InsightsState copyWith({
    bool? isLoading,
    List<WeekdayAverage>? weekdayAverages,
    BurnoutStatus? burnoutStatus,
    List<StartTimeBucket>? heatmap,
    ReportsLoadFailure? loadFailure,
  }) {
    return InsightsState(
      isLoading: isLoading ?? this.isLoading,
      weekdayAverages: weekdayAverages ?? this.weekdayAverages,
      burnoutStatus: burnoutStatus ?? this.burnoutStatus,
      heatmap: heatmap ?? this.heatmap,
      loadFailure: loadFailure ?? this.loadFailure,
    );
  }

  @override
  List<Object?> get props =>
      [isLoading, weekdayAverages, burnoutStatus, heatmap, loadFailure];
}
