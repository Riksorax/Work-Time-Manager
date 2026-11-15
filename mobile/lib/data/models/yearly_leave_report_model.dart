import '../../domain/entities/yearly_leave_report.dart';

/// Lesegrenze der Urlaubs- und Krankheitsauswertung (#284,
/// `GET /api/reports/yearly/{year}`): JSON → Entity.
///
/// Fehlende Zahlen gelten als 0, fehlt `year`, gilt [requestedYear];
/// unbekannte Felder werden ignoriert. Fehlen `months`, `vacationPeriods` oder
/// `sickPeriods` (älteres Backend), gelten leere Listen. Ist `months` gesetzt,
/// wird es auf genau zwölf Einträge (Monat 1–12) gebracht; fehlende Monate
/// sind 0, Einträge mit ungültiger Monatsnummer werden verworfen.
///
/// `start`/`end` der Zeiträume sind Kalendertage `yyyy-MM-dd`: Die Teile
/// werden zerlegt und als lokale Mitternacht gebaut, nie über eine Zeitzone
/// geparst (westlich von UTC wäre sonst der Vortag). Ein Zeitraum mit
/// ungültigem Datum wird verworfen.
YearlyLeaveReport yearlyLeaveReportFromJson(
  Map<String, dynamic> json, {
  required int requestedYear,
}) {
  return YearlyLeaveReport(
    year: (json['year'] as num?)?.toInt() ?? requestedYear,
    vacationDaysPerYear: _int(json['vacationDaysPerYear']),
    vacationDaysTaken: _int(json['vacationDaysTaken']),
    vacationDaysRemaining: _int(json['vacationDaysRemaining']),
    sickDays: _int(json['sickDays']),
    months: _months(json['months']),
    vacationPeriods: _periods(json['vacationPeriods']),
    sickPeriods: _periods(json['sickPeriods']),
  );
}

int _int(dynamic v) => v is num ? v.toInt() : 0;

List<YearlyLeaveMonth> _months(dynamic raw) {
  if (raw is! List) return const [];
  final byMonth = <int, YearlyLeaveMonth>{};
  for (final m in raw) {
    if (m is! Map<String, dynamic>) continue;
    final month = _int(m['month']);
    if (month < 1 || month > 12) continue;
    byMonth[month] = YearlyLeaveMonth(
      month: month,
      vacationDays: _int(m['vacationDays']),
      sickDays: _int(m['sickDays']),
    );
  }
  return [
    for (var month = 1; month <= 12; month++)
      byMonth[month] ??
          YearlyLeaveMonth(month: month, vacationDays: 0, sickDays: 0),
  ];
}

List<LeavePeriod> _periods(dynamic raw) {
  if (raw is! List) return const [];
  return [
    for (final p in raw)
      if (p is Map<String, dynamic>)
        if ((_calendarDay(p['start']), _calendarDay(p['end']))
            case (final DateTime start, final DateTime end))
          LeavePeriod(start: start, end: end, days: _int(p['days'])),
  ];
}

final _dayPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// `yyyy-MM-dd` als lokale Mitternacht; sonst `null`.
DateTime? _calendarDay(dynamic v) {
  if (v is! String) return null;
  final match = _dayPattern.firstMatch(v);
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime(year, month, day);
  // Kein Überlauf (z. B. 2026-02-30 → 2. März).
  if (date.year != year || date.month != month || date.day != day) {
    return null;
  }
  return date;
}
