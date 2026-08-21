/// Zentrale Helfer für die minutengenaue Zeiterfassung.
///
/// Die App erfasst, speichert und rechnet ausschließlich minutengenau.
/// Sekunden und Millisekunden werden dabei kaufmännisch gerundet
/// (ab 30 Sekunden auf, darunter ab). So stimmen die angezeigte Uhrzeit
/// (`HH:mm`) und der Wert, mit dem gerechnet wird, immer überein.
library;

/// Rundet einen Zeitstempel kaufmännisch auf die nächste volle Minute.
///
/// `08:00:29` -> `08:00`, `08:00:30` -> `08:01`.
DateTime roundToMinute(DateTime time) {
  final fraction = Duration(
    seconds: time.second,
    milliseconds: time.millisecond,
    microseconds: time.microsecond,
  );
  final floored = time.subtract(fraction);
  return fraction.inMicroseconds * 2 >= Duration.microsecondsPerMinute
      ? floored.add(const Duration(minutes: 1))
      : floored;
}

/// Wie [roundToMinute], akzeptiert aber `null` (z. B. für eine offene Endzeit).
DateTime? roundToMinuteOrNull(DateTime? time) =>
    time == null ? null : roundToMinute(time);

/// Der aktuelle Zeitpunkt, kaufmännisch auf die volle Minute gerundet.
///
/// Diese Funktion ist die einzige Quelle für automatisch erfasste Zeitstempel
/// (Arbeitsbeginn/-ende, Pausenbeginn/-ende).
DateTime nowToMinute() => roundToMinute(DateTime.now());

/// Rundet eine Dauer kaufmännisch auf volle Minuten.
///
/// Rundet symmetrisch: `+30s` -> `+1min`, `-30s` -> `-1min`. Damit driftet
/// eine Gleitzeit-Bilanz im Minus nicht anders als im Plus.
Duration roundDurationToMinute(Duration duration) => Duration(
      minutes: (duration.inMicroseconds / Duration.microsecondsPerMinute).round(),
    );

/// Eine Dauer als volle Minuten für die Persistenz (kaufmännisch gerundet).
int toStoredMinutes(Duration duration) =>
    roundDurationToMinute(duration).inMinutes;
