import 'package:equatable/equatable.dart';

/// Home-Office-Zahlen eines Zeitraums (Jahr oder Monat, #537), Abbild der
/// Felder von `HomeOfficeReportDto`/`HomeOfficeMonthDto`.
class HomeOfficeCounts extends Equatable {
  /// Tage mit erfasster Zeit, an denen im Home-Office gearbeitet wurde.
  final int homeOfficeDays;

  /// Tage mit erfasster Zeit ohne Home-Office-Flag.
  final int officeDays;

  /// Bezugstage: Home-Office plus Büro.
  final int totalDays;

  /// Anteil der Home-Office-Tage (0..1), `null` ohne Bezugstage.
  final double? ratio;

  const HomeOfficeCounts({
    required this.homeOfficeDays,
    required this.officeDays,
    required this.totalDays,
    required this.ratio,
  });

  static const empty = HomeOfficeCounts(
      homeOfficeDays: 0, officeDays: 0, totalDays: 0, ratio: null);

  @override
  List<Object?> get props => [homeOfficeDays, officeDays, totalDays, ratio];
}

/// Home-Office-Auswertung eines Kalenderjahres (#537). Angemeldet rechnet das
/// Backend (`GET /api/reports/home-office/{year}`), als Gast die lokale Regel
/// `calculateHomeOfficeStats`; die App stellt nur dar.
class HomeOfficeReport extends Equatable {
  final int year;
  final HomeOfficeCounts total;

  /// Immer zwölf Einträge, Index = Monat − 1.
  final List<HomeOfficeCounts> months;

  /// Aufsteigend sortierte Kalendertage (lokale Mitternacht) der
  /// Home-Office-Tage des Jahres.
  final List<DateTime> homeOfficeDates;

  const HomeOfficeReport({
    required this.year,
    required this.total,
    required this.months,
    required this.homeOfficeDates,
  });

  /// Werte des Monats [month] (1–12).
  HomeOfficeCounts month(int month) => months[month - 1];

  /// Home-Office-Tage des Monats [month] (1–12), aufsteigend.
  List<DateTime> datesInMonth(int month) => [
        for (final d in homeOfficeDates)
          if (d.month == month) d,
      ];

  @override
  List<Object?> get props => [year, total, months, homeOfficeDates];
}
