import 'package:equatable/equatable.dart';

import '../utils/insights_utils.dart';

/// Arbeitszeit-Insights über drei Kalendermonate (#134, #537), Abbild von
/// `InsightsReportDto`. Angemeldet rechnet das Backend
/// (`GET /api/reports/insights/{y}/{m}/{d}?tz=`), als Gast die lokalen
/// Funktionen aus `insights_utils.dart`; die App stellt nur dar.
class InsightsReport extends Equatable {
  /// Erster und letzter Kalendertag des Fensters (lokale Mitternacht).
  final DateTime from;
  final DateTime to;

  /// Tagessoll aus Wochenstunden und Arbeitstagen.
  final Duration dailyTarget;

  final List<WeekdayAverage> weekdayAverages;
  final BurnoutStatus burnoutStatus;

  /// Schwelle der Serien-Warnung in Tagen.
  final int warningThresholdDays;
  final List<StartTimeBucket> heatmap;

  const InsightsReport({
    required this.from,
    required this.to,
    required this.dailyTarget,
    required this.weekdayAverages,
    required this.burnoutStatus,
    required this.warningThresholdDays,
    required this.heatmap,
  });

  @override
  List<Object?> get props => [
        from,
        to,
        dailyTarget,
        weekdayAverages,
        burnoutStatus,
        warningThresholdDays,
        heatmap,
      ];
}
