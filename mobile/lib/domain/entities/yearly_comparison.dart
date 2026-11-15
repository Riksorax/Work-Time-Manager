import 'package:equatable/equatable.dart';

/// Kleinstes und größtes Jahr, das `GET /api/reports/yearly-comparison/{year}`
/// annimmt (#530): das Vorjahr muss in 2000–2100 liegen.
const int minComparisonYear = 2001;
const int maxComparisonYear = 2100;

/// `true`, wenn das Backend für [year] einen Jahresbericht liefert.
bool isComparisonYearSupported(int year) =>
    year >= minComparisonYear && year <= maxComparisonYear;

/// Jahresvergleich mit dem Vorjahr (#530), Abbild von `YearlyComparisonDto`.
/// Alle Werte rechnet das Backend (auch Differenzen und Prozentwert); die App
/// stellt nur dar.
class YearlyComparison extends Equatable {
  /// Stichtag `MM-dd` wie übergeben (beide Jahre nur bis einschließlich dieses
  /// Tags), `null` = ganzes Jahr.
  final String? until;
  final YearlySummary current;
  final YearlySummary previous;

  /// `current − previous` je Feld; `null`, wenn das Vorjahr keine Einträge hat.
  final YearlyDelta? delta;

  const YearlyComparison({
    required this.until,
    required this.current,
    required this.previous,
    required this.delta,
  });

  @override
  List<Object?> get props => [until, current, previous, delta];
}

/// Kennzahlen eines (ggf. am Stichtag abgeschnittenen) Kalenderjahres.
class YearlySummary extends Equatable {
  final int year;

  /// `false`: im (abgeschnittenen) Jahr gibt es keinen Eintrag, alle Werte 0.
  final bool hasData;

  /// Netto-Arbeitszeit (ohne Pausen; Urlaub/Krank/Feiertag mit Tagessoll).
  final Duration totalWorked;
  final Duration totalBreaks;

  /// Überstunden des Jahres (Summe der Monate), nicht der Gleitzeit-Saldo.
  final Duration overtime;
  final int workDays;
  final int vacationDays;
  final int sickDays;
  final int holidayDays;

  /// Immer 12 Einträge, Monat 1–12.
  final List<YearlySummaryMonth> months;

  const YearlySummary({
    required this.year,
    required this.hasData,
    required this.totalWorked,
    required this.totalBreaks,
    required this.overtime,
    required this.workDays,
    required this.vacationDays,
    required this.sickDays,
    required this.holidayDays,
    required this.months,
  });

  @override
  List<Object?> get props => [
        year,
        hasData,
        totalWorked,
        totalBreaks,
        overtime,
        workDays,
        vacationDays,
        sickDays,
        holidayDays,
        months,
      ];
}

/// Monatswerte eines Jahres (netto, Überstunden des Monats, Arbeitstage).
class YearlySummaryMonth extends Equatable {
  final int month;
  final Duration worked;
  final Duration overtime;
  final int workDays;

  const YearlySummaryMonth({
    required this.month,
    required this.worked,
    required this.overtime,
    required this.workDays,
  });

  @override
  List<Object?> get props => [month, worked, overtime, workDays];
}

/// Differenzen `current − previous`.
class YearlyDelta extends Equatable {
  final Duration worked;

  /// Prozent zur Netto-Arbeitszeit des Vorjahres, eine Nachkommastelle;
  /// `null`, wenn die Vorjahres-Arbeitszeit 0 ist.
  final double? workedPercent;
  final Duration overtime;
  final int workDays;
  final int vacationDays;
  final int sickDays;
  final int holidayDays;

  const YearlyDelta({
    required this.worked,
    required this.workedPercent,
    required this.overtime,
    required this.workDays,
    required this.vacationDays,
    required this.sickDays,
    required this.holidayDays,
  });

  @override
  List<Object?> get props => [
        worked,
        workedPercent,
        overtime,
        workDays,
        vacationDays,
        sickDays,
        holidayDays,
      ];
}
