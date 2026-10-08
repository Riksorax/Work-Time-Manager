import '../entities/work_entry_entity.dart';

/// Standard-Jahresurlaubsanspruch in Tagen (siehe #278).
const int defaultVacationDaysPerYear = 30;

/// Obergrenze für den eingestellten Jahresurlaubsanspruch.
const int maxVacationDaysPerYear = 366;

/// Urlaubs-/Krankheitsbilanz eines Kalenderjahres (siehe #278).
class LeaveBalance {
  final int year;
  final int entitlement;
  final int taken;

  /// Anspruch minus genommene Tage. Wird bewusst nicht auf 0 geklemmt,
  /// negative Werte bedeuten Überschreitung des Anspruchs.
  final int remaining;
  final int sickDays;

  const LeaveBalance({
    required this.year,
    required this.entitlement,
    required this.taken,
    required this.remaining,
    required this.sickDays,
  });

  @override
  bool operator ==(Object other) =>
      other is LeaveBalance &&
      other.year == year &&
      other.entitlement == entitlement &&
      other.taken == taken &&
      other.remaining == remaining &&
      other.sickDays == sickDays;

  @override
  int get hashCode =>
      Object.hash(year, entitlement, taken, remaining, sickDays);
}

/// Berechnet die Urlaubsbilanz für [year] aus [entries]. Einträge anderer
/// Jahre werden ignoriert. Regel identisch zum Backend `CalculateYearlyLeave`:
/// jeder `vacation`-Eintrag zählt als ein Tag (auch am Wochenende), `holiday`
/// zählt nie.
LeaveBalance calculateLeaveBalance(
  List<WorkEntryEntity> entries,
  int year,
  int entitlement,
) {
  var taken = 0;
  var sick = 0;
  for (final e in entries) {
    if (e.date.year != year) continue;
    switch (e.type) {
      case WorkEntryType.vacation:
        taken++;
      case WorkEntryType.sick:
        sick++;
      case WorkEntryType.holiday:
      case WorkEntryType.work:
        break;
    }
  }
  return LeaveBalance(
    year: year,
    entitlement: entitlement,
    taken: taken,
    remaining: entitlement - taken,
    sickDays: sick,
  );
}
