/// Antwort von `GET /api/reports/yearly/{year}` (#284) im Format des
/// Backends. Reine Testdaten; die Rechnung testet das Backend (die Summen
/// stimmen hier nur, damit die Daten in sich stimmig sind).
///
/// [empty] = Jahr ohne Urlaubs- und Krankheitstage.
Map<String, dynamic> yearlyLeaveReportJson(int year, {bool empty = false}) {
  final vacationByMonth = empty ? <int, int>{} : {8: 12, 12: 2};
  final sickByMonth = empty ? <int, int>{} : {2: 3, 11: 1};
  final taken = vacationByMonth.values.fold(0, (a, b) => a + b);
  return {
    'year': year,
    'vacationDaysPerYear': 30,
    'vacationDaysTaken': taken,
    'vacationDaysRemaining': 30 - taken,
    'sickDays': sickByMonth.values.fold(0, (a, b) => a + b),
    'months': [
      for (var m = 1; m <= 12; m++)
        {
          'month': m,
          'vacationDays': vacationByMonth[m] ?? 0,
          'sickDays': sickByMonth[m] ?? 0,
        },
    ],
    'vacationPeriods': empty
        ? <Map<String, dynamic>>[]
        : [
            {'start': '$year-08-03', 'end': '$year-08-14', 'days': 12},
            {'start': '$year-12-23', 'end': '$year-12-24', 'days': 2},
          ],
    'sickPeriods': empty
        ? <Map<String, dynamic>>[]
        : [
            {'start': '$year-02-10', 'end': '$year-02-12', 'days': 3},
            {'start': '$year-11-03', 'end': '$year-11-03', 'days': 1},
          ],
  };
}
