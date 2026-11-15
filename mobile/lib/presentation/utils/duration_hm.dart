/// Dauern im Format der Berichte (#531): `HH:MM`, Überstunden mit Vorzeichen
/// `+HH:MM`/`-HH:MM`. Minuten werden abgeschnitten, nicht gerundet (wie die
/// übrigen Berichtszeilen und das Web, `duration-format.util.ts`).
String formatDurationHm(Duration d) {
  final abs = d.abs();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(abs.inHours)}:${two(abs.inMinutes.remainder(60))}';
}

/// Wie [formatDurationHm], mit Vorzeichen; 0 ergibt `+00:00`.
String formatSignedDurationHm(Duration d) =>
    '${d.isNegative ? '-' : '+'}${formatDurationHm(d)}';
