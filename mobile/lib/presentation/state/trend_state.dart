import 'package:equatable/equatable.dart';

import '../../domain/entities/trend_report.dart';

/// Ladezustand der Trend-Ansicht (#531).
enum TrendStatus {
  /// Noch nicht angefordert (Ansicht nicht sichtbar, nicht angemeldet oder
  /// kein Premium).
  idle,
  loading,
  data,
  error,
}

/// Zustand der Trend-Ansicht: gewähltes Zeitfenster und Ladezustand. Die
/// Werte kommen fertig vom Backend; kein Offline-Fallback.
class TrendState extends Equatable {
  final TrendGranularity granularity;
  final TrendStatus status;

  /// Nur bei [TrendStatus.data] gesetzt.
  final TrendReport? report;

  const TrendState({
    this.granularity = TrendGranularity.week,
    this.status = TrendStatus.idle,
    this.report,
  });

  /// Geladen, aber in keinem der 12 Zeiträume ein Eintrag.
  bool get isEmpty => report != null && report!.isEmpty;

  @override
  List<Object?> get props => [granularity, status, report];
}
