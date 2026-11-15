import '../../domain/entities/yearly_comparison.dart';

/// Lesegrenze der Jahresvergleichs-Antwort (#530, `YearlyComparisonDto`):
/// JSON → Entity.
///
/// Dauern kommen in Millisekunden. Fehlende Felder gelten als 0 bzw. `false`
/// (fehlt `current`/`previous`, gilt ein leeres Jahr [requestedYear] bzw. das
/// Vorjahr); unbekannte Felder werden ignoriert. `months` wird auf genau zwölf
/// Einträge (Monat 1–12) gebracht; fehlende Monate sind 0, Einträge mit
/// ungültiger Monatsnummer werden verworfen. Kein Kalendertag wird gelesen:
/// `until` bleibt der Text `MM-dd` (oder `null`).
YearlyComparison yearlyComparisonFromJson(
  Map<String, dynamic> json, {
  required int requestedYear,
}) {
  final until = json['until'];
  final delta = json['delta'];
  return YearlyComparison(
    until: until is String ? until : null,
    current: _summaryFromJson(json['current'], requestedYear),
    previous: _summaryFromJson(json['previous'], requestedYear - 1),
    delta: delta is Map<String, dynamic> ? _deltaFromJson(delta) : null,
  );
}

Duration _ms(dynamic v) => Duration(milliseconds: (v as num?)?.toInt() ?? 0);

int _int(dynamic v) => (v as num?)?.toInt() ?? 0;

YearlySummary _summaryFromJson(dynamic raw, int fallbackYear) {
  final j = raw is Map<String, dynamic> ? raw : const <String, dynamic>{};
  final byMonth = <int, YearlySummaryMonth>{};
  for (final m in (j['months'] as List<dynamic>? ?? const [])) {
    if (m is! Map<String, dynamic>) continue;
    final month = _int(m['month']);
    if (month < 1 || month > 12) continue;
    byMonth[month] = YearlySummaryMonth(
      month: month,
      worked: _ms(m['workedMs']),
      overtime: _ms(m['overtimeMs']),
      workDays: _int(m['workDays']),
    );
  }
  return YearlySummary(
    year: (j['year'] as num?)?.toInt() ?? fallbackYear,
    hasData: (j['hasData'] as bool?) ?? false,
    totalWorked: _ms(j['totalWorkedMs']),
    totalBreaks: _ms(j['totalBreaksMs']),
    overtime: _ms(j['overtimeMs']),
    workDays: _int(j['workDays']),
    vacationDays: _int(j['vacationDays']),
    sickDays: _int(j['sickDays']),
    holidayDays: _int(j['holidayDays']),
    months: [
      for (var month = 1; month <= 12; month++)
        byMonth[month] ??
            YearlySummaryMonth(
              month: month,
              worked: Duration.zero,
              overtime: Duration.zero,
              workDays: 0,
            ),
    ],
  );
}

YearlyDelta _deltaFromJson(Map<String, dynamic> j) => YearlyDelta(
      worked: _ms(j['workedMs']),
      workedPercent: (j['workedPercent'] as num?)?.toDouble(),
      overtime: _ms(j['overtimeMs']),
      workDays: _int(j['workDays']),
      vacationDays: _int(j['vacationDays']),
      sickDays: _int(j['sickDays']),
      holidayDays: _int(j['holidayDays']),
    );
