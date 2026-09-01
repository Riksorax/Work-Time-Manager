/// Zentrale Helfer für die minutengenaue Zeiterfassung.
///
/// Die App erfasst, speichert und rechnet ausschließlich minutengenau.
/// Erfasste Zeitstempel (Start, Ende, Pausen) werden dafür auf die volle
/// Minute abgeschnitten statt gerundet — eine Uhrzeit darf nie in der
/// Zukunft liegen (relativ zum tatsächlichen Moment der Erfassung), sonst
/// wirkt es, als würde die App die Zeit manipulieren. Dauern (z. B. für
/// den Gleitzeit-Saldo) werden dagegen weiterhin kaufmännisch gerundet,
/// siehe [roundDurationToMinute].
library;

/// Schneidet einen Zeitstempel auf die volle Minute ab (Sekunden,
/// Millisekunden und Mikrosekunden werden verworfen, nicht gerundet).
///
/// `08:00:29` -> `08:00`, `08:00:59` -> `08:00`.
DateTime roundToMinute(DateTime time) {
  final fraction = Duration(
    seconds: time.second,
    milliseconds: time.millisecond,
    microseconds: time.microsecond,
  );
  return time.subtract(fraction);
}

/// Wie [roundToMinute], akzeptiert aber `null` (z. B. für eine offene Endzeit).
DateTime? roundToMinuteOrNull(DateTime? time) =>
    time == null ? null : roundToMinute(time);

/// Der aktuelle Zeitpunkt, auf die volle Minute abgeschnitten.
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
