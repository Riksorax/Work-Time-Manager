import 'package:equatable/equatable.dart';

/// Urlaubs- und Krankheitsauswertung eines Kalenderjahres (#284), Abbild der
/// Antwort von `GET /api/reports/yearly/{year}`. Alle Werte rechnet das
/// Backend (Summen, Monate, zusammengefasste Zeiträume); die App stellt nur
/// dar und rechnet nicht nach.
class YearlyLeaveReport extends Equatable {
  final int year;
  final int vacationDaysPerYear;
  final int vacationDaysTaken;
  final int vacationDaysRemaining;
  final int sickDays;

  /// Monate 1 bis 12 (genau zwölf Einträge) oder leer, wenn ein älteres
  /// Backend das Feld nicht liefert.
  final List<YearlyLeaveMonth> months;

  /// Aufsteigend sortiert, auf das Jahr beschnitten (wie vom Backend).
  final List<LeavePeriod> vacationPeriods;
  final List<LeavePeriod> sickPeriods;

  const YearlyLeaveReport({
    required this.year,
    required this.vacationDaysPerYear,
    required this.vacationDaysTaken,
    required this.vacationDaysRemaining,
    required this.sickDays,
    required this.months,
    required this.vacationPeriods,
    required this.sickPeriods,
  });

  /// Weder Urlaubs- noch Krankheitstage im Jahr (Werte des Backends).
  bool get isEmpty => vacationDaysTaken == 0 && sickDays == 0;

  @override
  List<Object?> get props => [
        year,
        vacationDaysPerYear,
        vacationDaysTaken,
        vacationDaysRemaining,
        sickDays,
        months,
        vacationPeriods,
        sickPeriods,
      ];
}

/// Urlaubs- und Krankheitstage eines Monats.
class YearlyLeaveMonth extends Equatable {
  final int month;
  final int vacationDays;
  final int sickDays;

  const YearlyLeaveMonth({
    required this.month,
    required this.vacationDays,
    required this.sickDays,
  });

  @override
  List<Object?> get props => [month, vacationDays, sickDays];
}

/// Zusammenhängender Zeitraum mit Urlaub bzw. Krankheit.
///
/// [start] und [end] sind die **lokale Mitternacht** des Kalendertags
/// (aus `yyyy-MM-dd` zerlegt, nie über eine Zeitzone gelesen, siehe #418).
class LeavePeriod extends Equatable {
  final DateTime start;
  final DateTime end;
  final int days;

  const LeavePeriod({
    required this.start,
    required this.end,
    required this.days,
  });

  @override
  List<Object?> get props => [start, end, days];
}
