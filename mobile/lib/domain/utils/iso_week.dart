/// ISO-8601-Kalenderwoche (Montag = Wochenbeginn, Woche 1 enthaelt den
/// ersten Donnerstag des Jahres).
///
/// Rechnet nur mit den Kalenderfeldern (Jahr/Monat/Tag) in UTC und ist damit
/// unabhaengig von Sommerzeit, Prozess-Zeitzone und Uhrzeit. Entspricht dem
/// Backend (`ReportCalculator.GetIsoWeekNumber`).
int isoWeekNumber(DateTime date) {
  final thursday = _thursdayOfWeek(date);
  final jan1 = DateTime.utc(thursday.year, 1, 1);
  final dayOfYear = thursday.difference(jan1).inDays + 1;
  return (dayOfYear - 1) ~/ 7 + 1;
}

/// ISO-Wochenjahr des Datums (kann am Jahreswechsel vom Kalenderjahr
/// abweichen, z. B. 2027-01-01 -> 2026).
int isoWeekYear(DateTime date) => _thursdayOfWeek(date).year;

DateTime _thursdayOfWeek(DateTime date) {
  final utc = DateTime.utc(date.year, date.month, date.day);
  return DateTime.utc(utc.year, utc.month, utc.day + (4 - utc.weekday));
}
