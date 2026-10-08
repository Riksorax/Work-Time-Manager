import '../entities/bundesland.dart';
import 'date_utils.dart';

/// Berechnet die gesetzlichen Feiertage eines Bundeslands für ein
/// Kalenderjahr (siehe #222).
///
/// Reine Funktion ohne Seiteneffekte. Deckt die aktuell (Stand 2026)
/// bundesweit sowie landesspezifisch geltenden Feiertage ab. Vereinfachung:
/// Mariä Himmelfahrt und Fronleichnam gelten in einigen Bundesländern nur in
/// überwiegend katholischen Gemeinden - hier landesweit angenommen, da eine
/// gemeindegenaue Zuordnung den Rahmen dieses Features sprengen würde.
///
/// Die Rückgabe enthält reine Datums-DateTimes (lokale Mitternacht, nicht UTC).
List<DateTime> getGermanHolidays(int year, Bundesland bundesland) {
  return getGermanHolidayIds(year, bundesland).keys.toList();
}

/// Sprachneutrale ID eines gesetzlichen Feiertags (siehe #279). Die
/// Anzeigenamen werden in der Presentation-Schicht lokalisiert.
enum GermanHoliday {
  newYear,
  goodFriday,
  easterMonday,
  labourDay,
  ascension,
  whitMonday,
  germanUnityDay,
  christmasDay1,
  christmasDay2,
  epiphany,
  corpusChristi,
  assumption,
  reformationDay,
  allSaints,
  womensDay,
  worldChildrensDay,
  repentanceDay,
}

/// Liefert die Feiertage eines Bundeslands als sprachneutrale IDs (siehe #279);
/// die Anzeigenamen werden in der Presentation-Schicht lokalisiert (#369).
///
/// Die Schluessel sind reine Datums-DateTimes (lokale Mitternacht, nicht UTC).
Map<DateTime, GermanHoliday> getGermanHolidayIds(
    int year, Bundesland bundesland) {
  final easter = _calculateEasterSunday(year);

  final holidays = <DateTime, GermanHoliday>{
    DateTime(year, 1, 1): GermanHoliday.newYear,
    addCalendarDays(easter, -2): GermanHoliday.goodFriday,
    addCalendarDays(easter, 1): GermanHoliday.easterMonday,
    DateTime(year, 5, 1): GermanHoliday.labourDay,
    addCalendarDays(easter, 39): GermanHoliday.ascension,
    addCalendarDays(easter, 50): GermanHoliday.whitMonday,
    DateTime(year, 10, 3): GermanHoliday.germanUnityDay,
    DateTime(year, 12, 25): GermanHoliday.christmasDay1,
    DateTime(year, 12, 26): GermanHoliday.christmasDay2,
  };

  final epiphany = DateTime(year, 1, 6);
  final corpusChristi = addCalendarDays(easter, 60);
  final assumption = DateTime(year, 8, 15);
  final reformationDay = DateTime(year, 10, 31);
  final allSaints = DateTime(year, 11, 1);

  switch (bundesland) {
    case Bundesland.badenWuerttemberg:
      holidays[epiphany] = GermanHoliday.epiphany;
      holidays[corpusChristi] = GermanHoliday.corpusChristi;
      holidays[allSaints] = GermanHoliday.allSaints;
      break;
    case Bundesland.bayern:
      holidays[epiphany] = GermanHoliday.epiphany;
      holidays[corpusChristi] = GermanHoliday.corpusChristi;
      holidays[assumption] = GermanHoliday.assumption;
      holidays[allSaints] = GermanHoliday.allSaints;
      break;
    case Bundesland.berlin:
      holidays[DateTime(year, 3, 8)] = GermanHoliday.womensDay;
      break;
    case Bundesland.brandenburg:
    case Bundesland.bremen:
    case Bundesland.hamburg:
    case Bundesland.niedersachsen:
    case Bundesland.schleswigHolstein:
      holidays[reformationDay] = GermanHoliday.reformationDay;
      break;
    case Bundesland.hessen:
      holidays[corpusChristi] = GermanHoliday.corpusChristi;
      break;
    case Bundesland.mecklenburgVorpommern:
      holidays[DateTime(year, 3, 8)] = GermanHoliday.womensDay;
      holidays[reformationDay] = GermanHoliday.reformationDay;
      break;
    case Bundesland.nordrheinWestfalen:
    case Bundesland.rheinlandPfalz:
      holidays[corpusChristi] = GermanHoliday.corpusChristi;
      holidays[allSaints] = GermanHoliday.allSaints;
      break;
    case Bundesland.saarland:
      holidays[corpusChristi] = GermanHoliday.corpusChristi;
      holidays[assumption] = GermanHoliday.assumption;
      holidays[allSaints] = GermanHoliday.allSaints;
      break;
    case Bundesland.sachsen:
      holidays[reformationDay] = GermanHoliday.reformationDay;
      holidays[_bussUndBettag(year)] = GermanHoliday.repentanceDay;
      break;
    case Bundesland.sachsenAnhalt:
      holidays[epiphany] = GermanHoliday.epiphany;
      holidays[reformationDay] = GermanHoliday.reformationDay;
      break;
    case Bundesland.thueringen:
      holidays[DateTime(year, 9, 20)] = GermanHoliday.worldChildrensDay;
      holidays[reformationDay] = GermanHoliday.reformationDay;
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
    date = addCalendarDays(date, -1);
  }
  return date;
}
