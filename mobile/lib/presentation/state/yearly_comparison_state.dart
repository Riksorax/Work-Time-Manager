import 'package:equatable/equatable.dart';

import '../../domain/entities/yearly_comparison.dart';

/// Ladezustand des Jahresvergleichs (#530).
enum YearlyComparisonStatus {
  /// Noch nicht angefordert (Karte nicht sichtbar, nicht angemeldet oder kein
  /// Premium).
  idle,

  /// Das Backend kennt für dieses Jahr keinen Vergleich (vor 2001 bzw. nach
  /// 2100); es wird nichts angefragt.
  unsupported,
  loading,
  data,
  error,
}

/// Zustand der Vergleichskarte im Jahres-Tab. Die Werte kommen fertig vom
/// Backend; kein Offline-Fallback.
class YearlyComparisonState extends Equatable {
  /// Gewähltes Jahr des Jahres-Tabs.
  final int year;
  final YearlyComparisonStatus status;

  /// Nur bei [YearlyComparisonStatus.data] gesetzt.
  final YearlyComparison? report;

  const YearlyComparisonState({
    required this.year,
    this.status = YearlyComparisonStatus.idle,
    this.report,
  });

  @override
  List<Object?> get props => [year, status, report];
}
