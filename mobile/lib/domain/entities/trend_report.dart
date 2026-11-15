import 'package:equatable/equatable.dart';

/// Zeitfenster des Trends (#531): 12 ISO-Wochen oder 12 Kalendermonate bis
/// zum Bezugstag. [apiValue] ist der Query-Parameter `granularity`.
enum TrendGranularity {
  week('week'),
  month('month');

  const TrendGranularity(this.apiValue);

  final String apiValue;
}

/// Ein Zeitraum (Woche Mo–So bzw. Kalendermonat) des Trends. Alle Werte kommen
/// fertig gerechnet vom Backend (`TrendBucketDto`); die App rechnet nichts nach.
class TrendBucket extends Equatable {
  /// `yyyy-Www` (ISO-Wochenjahr + KW) bzw. `yyyy-MM`.
  final String key;

  /// Erster Kalendertag als lokale Mitternacht (aus der UTC-Mitternacht des
  /// Backends gelesen, nie über `.toLocal()`, siehe #418).
  final DateTime start;

  /// Letzter Kalendertag als lokale Mitternacht.
  final DateTime end;

  /// Netto-Arbeitszeit des Zeitraums.
  final Duration worked;

  /// Soll des Zeitraums.
  final Duration target;

  /// Überstunden des Zeitraums.
  final Duration overtime;

  /// Laufende Summe der Überstunden ab dem ersten Zeitraum (ab 0, nicht der
  /// Gleitzeit-Saldo).
  final Duration cumulativeOvertime;

  /// `false`: keine Einträge im Zeitraum (Werte 0, als Lücke gezeichnet).
  final bool hasData;

  const TrendBucket({
    required this.key,
    required this.start,
    required this.end,
    required this.worked,
    required this.target,
    required this.overtime,
    required this.cumulativeOvertime,
    required this.hasData,
  });

  /// Kalenderwoche aus dem Schlüssel `yyyy-Www`, sonst `null`.
  int? get weekNumber => weekNumberOfKey(key);

  @override
  List<Object?> get props => [
        key,
        start,
        end,
        worked,
        target,
        overtime,
        cumulativeOvertime,
        hasData,
      ];
}

/// Kennzahl „Wochen-Trend“: letzte abgeschlossene Woche gegen den Durchschnitt
/// der Wochen davor (`WeeklyTrendDto`).
class WeeklyTrend extends Equatable {
  /// `yyyy-Www` der letzten abgeschlossenen Woche.
  final String lastWeekKey;
  final Duration lastWeekWorked;
  final Duration averageWorked;
  final Duration delta;

  /// Anzahl der eingerechneten Vergleichswochen (2–4).
  final int comparedWeeks;

  const WeeklyTrend({
    required this.lastWeekKey,
    required this.lastWeekWorked,
    required this.averageWorked,
    required this.delta,
    required this.comparedWeeks,
  });

  int? get lastWeekNumber => weekNumberOfKey(lastWeekKey);

  @override
  List<Object?> get props =>
      [lastWeekKey, lastWeekWorked, averageWorked, delta, comparedWeeks];
}

/// Antwort von `GET /api/reports/trend/{y}/{m}/{d}` (#531).
class TrendReport extends Equatable {
  final TrendGranularity granularity;

  /// Immer 12, älteste zuerst; der letzte enthält den Bezugstag und läuft ggf.
  /// noch.
  final List<TrendBucket> buckets;

  /// `null`: zu wenig Daten für den Wochen-Trend.
  final WeeklyTrend? weeklyTrend;

  const TrendReport({
    required this.granularity,
    required this.buckets,
    required this.weeklyTrend,
  });

  /// Kein Zeitraum mit Einträgen.
  bool get isEmpty => buckets.every((b) => !b.hasData);

  @override
  List<Object?> get props => [granularity, buckets, weeklyTrend];
}

/// Kalenderwoche aus `yyyy-Www`, sonst `null`.
int? weekNumberOfKey(String key) {
  final i = key.indexOf('-W');
  if (i < 0) return null;
  return int.tryParse(key.substring(i + 2));
}
