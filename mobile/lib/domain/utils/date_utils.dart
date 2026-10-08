/// Kalenderarithmetik statt `Duration(days: n)`-Addition: bleibt auch über
/// Zeitumstellungen (Sommer-/Winterzeit) hinweg exakt auf lokaler Mitternacht
/// (siehe #362). Die Uhrzeit von [date] wird verworfen.
DateTime addCalendarDays(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);

/// Alle Kalendertage von [start] bis [end] (jeweils inklusive) als lokale
/// Mitternacht. Die Reihenfolge der Argumente spielt keine Rolle.
List<DateTime> datesInRange(DateTime start, DateTime end) {
  var first = DateTime(start.year, start.month, start.day);
  var last = DateTime(end.year, end.month, end.day);
  if (last.isBefore(first)) {
    final tmp = first;
    first = last;
    last = tmp;
  }
  final days = <DateTime>[];
  for (var d = first; !d.isAfter(last); d = addCalendarDays(d, 1)) {
    days.add(d);
  }
  return days;
}

/// Verschiebt einen Wochenstart um [weeks] Wochen (negativ = zurück).
DateTime shiftWeekStart(DateTime weekStart, int weeks) =>
    addCalendarDays(weekStart, 7 * weeks);

/// Kombiniert den Kalendertag von [day] mit der Uhrzeit [hour]:[minute] zu
/// einer lokalen Zeit (Sekunden/Millisekunden = 0). Die Uhrzeit von [day]
/// wird verworfen. Bewusst Kalender- statt Dauer-Arithmetik: bleibt über
/// Zeitumstellungen hinweg am selben Tag (nicht existierende Zeiten
/// normalisiert Dart, siehe #397).
DateTime combineDateAndTime(DateTime day, int hour, int minute) =>
    DateTime(day.year, day.month, day.day, hour, minute);
