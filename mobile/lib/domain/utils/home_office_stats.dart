/// Home-Office-Auswertung (#282): einzige Stelle der Zählregel.
///
/// Gezählt werden Arbeitstage mit erfasster Zeit: `type == work` und
/// `workStart != null` (offene Einträge zählen, leere manuelle Einträge nicht).
/// Urlaub, Krankheit und Feiertage zählen nie, auch nicht mit gesetztem Flag.
/// Mehrere Einträge am selben Kalendertag (`entryDay`, #418) zählen einmal; der
/// Tag ist Home-Office, wenn irgendein Eintrag das Flag trägt.
library;

import 'package:intl/intl.dart';

import '../entities/home_office_report.dart';
import '../entities/work_entry_entity.dart';
import 'entry_day.dart';

class HomeOfficeStats {
  /// Tage mit erfasster Zeit, an denen im Home-Office gearbeitet wurde.
  final int homeOfficeDays;

  /// Tage mit erfasster Zeit ohne Home-Office-Flag.
  final int officeDays;

  /// Aufsteigend sortierte Kalendertage (lokale Mitternacht) der Home-Office-Tage.
  final List<DateTime> homeOfficeDates;

  const HomeOfficeStats({
    required this.homeOfficeDays,
    required this.officeDays,
    required this.homeOfficeDates,
  });

  /// Bezugstage: Home-Office plus Büro.
  int get totalDays => homeOfficeDays + officeDays;

  /// Anteil der Home-Office-Tage (0..1), `null` ohne Bezugstage.
  double? get ratio => totalDays == 0 ? null : homeOfficeDays / totalDays;

  /// Dieselben Zahlen in der Form der Backend-Antwort (#537).
  HomeOfficeCounts toCounts() => HomeOfficeCounts(
        homeOfficeDays: homeOfficeDays,
        officeDays: officeDays,
        totalDays: totalDays,
        ratio: ratio,
      );
}

HomeOfficeStats calculateHomeOfficeStats(List<WorkEntryEntity> entries) {
  final days = <DateTime, bool>{};
  for (final e in entries) {
    if (e.type != WorkEntryType.work || e.workStart == null) continue;
    final day = entryDay(e);
    days[day] = (days[day] ?? false) || e.isHomeOffice;
  }
  final homeOfficeDates = [
    for (final d in days.entries)
      if (d.value) d.key,
  ]..sort();
  final homeOffice = homeOfficeDates.length;
  return HomeOfficeStats(
    homeOfficeDays: homeOffice,
    officeDays: days.length - homeOffice,
    homeOfficeDates: homeOfficeDates,
  );
}

/// Lokale Jahresauswertung (Gast-Modus, #537) aus den Einträgen je Monat
/// ([entriesPerMonth], Index = Monat − 1): Jahr über alle Einträge, Monat je
/// Monat, wie bisher der Home-Office-Jahresexport.
HomeOfficeReport homeOfficeReportFromEntries(
    int year, List<List<WorkEntryEntity>> entriesPerMonth) {
  final total = calculateHomeOfficeStats([
    for (final entries in entriesPerMonth) ...entries,
  ]);
  return HomeOfficeReport(
    year: year,
    total: total.toCounts(),
    months: [
      for (final entries in entriesPerMonth)
        calculateHomeOfficeStats(entries).toCounts(),
    ],
    homeOfficeDates: total.homeOfficeDates,
  );
}

/// Formatiert den Anteil mit einer Nachkommastelle und Prozentzeichen
/// ("33,3 %" in de, "33.3%" in en); `null` ergibt "-".
String formatHomeOfficeRatio(double? ratio, String locale) {
  if (ratio == null) return '-';
  return NumberFormat.decimalPercentPattern(locale: locale, decimalDigits: 1)
      .format(ratio);
}
