/// Art der Gleitzeit-Schwellwert-Warnung (siehe #219).
enum OvertimeWarningType { none, overtime, undertime }

/// Prüft, ob der aktuelle Gleitzeitsaldo [totalOvertime] einen der
/// konfigurierten Schwellwerte über- bzw. unterschreitet.
///
/// Reine Funktion ohne Seiteneffekte - der Aufrufer entscheidet, ob und wie
/// eine Benachrichtigung ausgelöst wird.
OvertimeWarningType checkOvertimeWarning({
  required Duration totalOvertime,
  required bool warnOnOvertime,
  required double overtimeThresholdHours,
  required bool warnOnUndertime,
  required double undertimeThresholdHours,
}) {
  final minutes = totalOvertime.inMinutes;

  if (warnOnOvertime && minutes >= (overtimeThresholdHours * 60).round()) {
    return OvertimeWarningType.overtime;
  }

  if (warnOnUndertime && minutes <= -(undertimeThresholdHours * 60).round()) {
    return OvertimeWarningType.undertime;
  }

  return OvertimeWarningType.none;
}
