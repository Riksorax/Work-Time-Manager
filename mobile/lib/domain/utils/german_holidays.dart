import '../entities/bundesland.dart';

/// Berechnet die gesetzlichen Feiertage eines Bundeslands für ein
/// Kalenderjahr (siehe #222).
///
/// Reine Funktion ohne Seiteneffekte. Deckt die aktuell (Stand 2026)
/// bundesweit sowie landesspezifisch geltenden Feiertage ab. Vereinfachung:
/// Mariä Himmelfahrt und Fronleichnam gelten in einigen Bundesländern nur in
/// überwiegend katholischen Gemeinden - hier landesweit angenommen, da eine
/// gemeindegenaue Zuordnung den Rahmen dieses Features sprengen würde.
List<DateTime> getGermanHolidays(int year, Bundesland bundesland) {
  return getGermanHolidayNames(year, bundesland).keys.toList();
}

/// Wie [getGermanHolidays], liefert aber zusätzlich den Namen jedes
/// Feiertags (siehe #253 - im Kalender waren Feiertage bisher nur rot
/// markiert, ohne dass ersichtlich war, um welchen Feiertag es sich
/// handelt).
Map<DateTime, String> getGermanHolidayNames(int year, Bundesland bundesland) {
  final easter = _calculateEasterSunday(year);

  final holidays = <DateTime, String>{
    DateTime(year, 1, 1): 'Neujahr',
    easter.subtract(const Duration(days: 2)): 'Karfreitag',
    easter.add(const Duration(days: 1)): 'Ostermontag',
    DateTime(year, 5, 1): 'Tag der Arbeit',
    easter.add(const Duration(days: 39)): 'Christi Himmelfahrt',
    easter.add(const Duration(days: 50)): 'Pfingstmontag',
    DateTime(year, 10, 3): 'Tag der Deutschen Einheit',
    DateTime(year, 12, 25): '1. Weihnachtsfeiertag',
    DateTime(year, 12, 26): '2. Weihnachtsfeiertag',
  };

  final heiligeDreiKoenige = DateTime(year, 1, 6);
  final fronleichnam = easter.add(const Duration(days: 60));
  final mariaeHimmelfahrt = DateTime(year, 8, 15);
  final reformationstag = DateTime(year, 10, 31);
  final allerheiligen = DateTime(year, 11, 1);

  switch (bundesland) {
    case Bundesland.badenWuerttemberg:
      holidays[heiligeDreiKoenige] = 'Heilige Drei Könige';
      holidays[fronleichnam] = 'Fronleichnam';
      holidays[allerheiligen] = 'Allerheiligen';
      break;
    case Bundesland.bayern:
      holidays[heiligeDreiKoenige] = 'Heilige Drei Könige';
      holidays[fronleichnam] = 'Fronleichnam';
      holidays[mariaeHimmelfahrt] = 'Mariä Himmelfahrt';
      holidays[allerheiligen] = 'Allerheiligen';
      break;
    case Bundesland.berlin:
      holidays[DateTime(year, 3, 8)] = 'Internationaler Frauentag';
      break;
    case Bundesland.brandenburg:
      holidays[reformationstag] = 'Reformationstag';
      break;
    case Bundesland.bremen:
      holidays[reformationstag] = 'Reformationstag';
      break;
    case Bundesland.hamburg:
      holidays[reformationstag] = 'Reformationstag';
      break;
    case Bundesland.hessen:
      holidays[fronleichnam] = 'Fronleichnam';
      break;
    case Bundesland.mecklenburgVorpommern:
      holidays[DateTime(year, 3, 8)] = 'Internationaler Frauentag';
      holidays[reformationstag] = 'Reformationstag';
      break;
    case Bundesland.niedersachsen:
      holidays[reformationstag] = 'Reformationstag';
      break;
    case Bundesland.nordrheinWestfalen:
      holidays[fronleichnam] = 'Fronleichnam';
      holidays[allerheiligen] = 'Allerheiligen';
      break;
    case Bundesland.rheinlandPfalz:
      holidays[fronleichnam] = 'Fronleichnam';
      holidays[allerheiligen] = 'Allerheiligen';
      break;
    case Bundesland.saarland:
      holidays[fronleichnam] = 'Fronleichnam';
      holidays[mariaeHimmelfahrt] = 'Mariä Himmelfahrt';
      holidays[allerheiligen] = 'Allerheiligen';
      break;
    case Bundesland.sachsen:
      holidays[reformationstag] = 'Reformationstag';
      holidays[_bussUndBettag(year)] = 'Buß- und Bettag';
      break;
    case Bundesland.sachsenAnhalt:
      holidays[heiligeDreiKoenige] = 'Heilige Drei Könige';
      holidays[reformationstag] = 'Reformationstag';
      break;
    case Bundesland.schleswigHolstein:
      holidays[reformationstag] = 'Reformationstag';
      break;
    case Bundesland.thueringen:
      holidays[DateTime(year, 9, 20)] = 'Weltkindertag';
      holidays[reformationstag] = 'Reformationstag';
      break;
  }

  return holidays;
}

/// Berechnet den Ostersonntag nach dem gaußschen Osteralgorithmus
/// (Meeus/Jones/Butcher, gregorianischer Kalender).
DateTime _calculateEasterSunday(int year) {
  final a = year % 19;
  final b = year ~/ 100;
  final c = year % 100;
  final d = b ~/ 4;
  final e = b % 4;
  final f = (b + 8) ~/ 25;
  final g = (b - f + 1) ~/ 3;
  final h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4;
  final k = c % 4;
  final l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final month = (h + l - 7 * m + 114) ~/ 31;
  final day = ((h + l - 7 * m + 114) % 31) + 1;
  return DateTime(year, month, day);
}

/// Buß- und Bettag: Mittwoch vor dem 23. November (fällt immer zwischen dem
/// 16. und 22. November). Nur in Sachsen gesetzlicher Feiertag.
DateTime _bussUndBettag(int year) {
  var date = DateTime(year, 11, 22);
  while (date.weekday != DateTime.wednesday) {
    date = date.subtract(const Duration(days: 1));
  }
  return date;
}
