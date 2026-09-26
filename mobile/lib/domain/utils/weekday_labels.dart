import 'package:intl/intl.dart';

/// Kurzes, lokalisiertes Wochentags-Label für einen ISO-Wochentag (1 = Montag
/// ... 7 = Sonntag). 1.1.2024 ist bewusst als Referenzdatum gewählt, da es
/// ein Montag ist. Gemeinsam genutzt von der Arbeitstage-Auswahl und ihrer
/// Anzeige in den Einstellungen (siehe #217, #221).
String weekdayShortLabel(int isoWeekday, String locale) {
  return DateFormat.E(locale).format(DateTime(2024, 1, isoWeekday));
}

/// Formatiert eine Menge von ISO-Wochentagen (1-7) als kurze, sortierte,
/// komma-getrennte Liste (z.B. "Di, Mi, Do, Fr, Sa").
String formatWorkdays(List<int> workdays, String locale) {
  final sorted = [...workdays]..sort();
  return sorted.map((d) => weekdayShortLabel(d, locale)).join(', ');
}
