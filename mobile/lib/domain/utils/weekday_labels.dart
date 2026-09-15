/// Kurze deutsche Wochentags-Labels, indiziert nach ISO-Wochentag - 1
/// (0 = Montag ... 6 = Sonntag). Gemeinsam genutzt von der Arbeitstage-
/// Auswahl und ihrer Anzeige in den Einstellungen (siehe #217).
const List<String> germanWeekdayShortLabels = [
  'Mo',
  'Di',
  'Mi',
  'Do',
  'Fr',
  'Sa',
  'So',
];

/// Formatiert eine Menge von ISO-Wochentagen (1-7) als kurze, sortierte,
/// komma-getrennte Liste (z.B. "Di, Mi, Do, Fr, Sa").
String formatWorkdays(List<int> workdays) {
  final sorted = [...workdays]..sort();
  return sorted.map((d) => germanWeekdayShortLabels[d - 1]).join(', ');
}
