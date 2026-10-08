// Brute-Force-Limit der App-Sperre (siehe #358). Reine Logik ohne
// Flutter-Abhängigkeiten und ohne Texte.

/// Anzahl Fehlversuche ohne Wartezeit.
const int appLockFreeAttempts = 2;

/// Toleranz, ab der eine zurückgestellte Uhr erkannt wird.
const Duration appLockClockTolerance = Duration(minutes: 2);

/// Wartezeit nach dem [failedAttempts]-ten Fehlversuch: 1-2 frei, 3-4 5 s,
/// 5-6 30 s, ab 7 Deckel bei 300 s.
Duration lockoutDurationFor(int failedAttempts) {
  if (failedAttempts <= appLockFreeAttempts) return Duration.zero;
  if (failedAttempts <= 4) return const Duration(seconds: 5);
  if (failedAttempts <= 6) return const Duration(seconds: 30);
  return const Duration(seconds: 300);
}

/// Ergebnis eines gezählten Entsperrversuchs.
sealed class AttemptResult {
  const AttemptResult();
}

class AttemptSuccess extends AttemptResult {
  const AttemptSuccess();
}

/// Falscher Versuch; [remaining] ist die neue Wartezeit (ggf. [Duration.zero]).
class AttemptWrong extends AttemptResult {
  final Duration remaining;
  const AttemptWrong(this.remaining);
}

/// Versuch abgelehnt, weil die Sperre noch läuft (nicht gezählt).
class AttemptLocked extends AttemptResult {
  final Duration remaining;
  const AttemptLocked(this.remaining);
}

/// Formatiert die Restdauer als `mm:ss`; Sekunden werden aufgerundet, damit
/// bei aktiver Sperre nie `00:00` erscheint.
String formatLockoutCountdown(Duration d) {
  final totalSeconds = d.isNegative ? 0 : (d.inMilliseconds + 999) ~/ 1000;
  final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
  final s = (totalSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}
