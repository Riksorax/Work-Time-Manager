import '../../domain/entities/home_office_report.dart';
import '../../domain/utils/entry_day.dart';

/// Lesegrenze der Home-Office-Antwort (#537, `HomeOfficeReportDto`):
/// JSON → Entity.
///
/// Fehlende Zahlen gelten als 0, ein fehlender oder nicht numerischer Anteil
/// als `null`. `months` wird auf genau zwölf Einträge (Monat 1–12) gebracht;
/// fehlende Monate sind leer, ungültige Monatsnummern werden verworfen.
/// `homeOfficeDates` sind Kalendertage `yyyy-MM-dd` und werden zur lokalen
/// Mitternacht zerlegt, nie über eine Zone gelesen (#418); ungültige Einträge
/// entfallen, das Ergebnis ist aufsteigend sortiert.
HomeOfficeReport homeOfficeReportFromJson(
  Map<String, dynamic> json, {
  required int requestedYear,
}) {
  final byMonth = <int, HomeOfficeCounts>{};
  for (final m in (json['months'] as List<dynamic>? ?? const [])) {
    if (m is! Map<String, dynamic>) continue;
    final month = _int(m['month']);
    if (month < 1 || month > 12) continue;
    byMonth[month] = _counts(m);
  }
  final dates = <DateTime>[
    for (final d in (json['homeOfficeDates'] as List<dynamic>? ?? const []))
      if (d is String && localDateFromEntryId(_dayPart(d)) != null)
        localDateFromEntryId(_dayPart(d))!,
  ]..sort();
  return HomeOfficeReport(
    year: (json['year'] as num?)?.toInt() ?? requestedYear,
    total: _counts(json),
    months: [
      for (var month = 1; month <= 12; month++)
        byMonth[month] ?? HomeOfficeCounts.empty,
    ],
    homeOfficeDates: dates,
  );
}

HomeOfficeCounts _counts(Map<String, dynamic> j) => HomeOfficeCounts(
      homeOfficeDays: _int(j['homeOfficeDays']),
      officeDays: _int(j['officeDays']),
      totalDays: _int(j['totalDays']),
      ratio: (j['homeOfficeRatio'] as num?)?.toDouble(),
    );

int _int(dynamic v) => v is num ? v.toInt() : 0;

/// `yyyy-MM-dd` eines Tages; ein Zeitanteil (`…T00:00:00`) wird ignoriert.
String _dayPart(String s) => s.length >= 10 ? s.substring(0, 10) : s;
