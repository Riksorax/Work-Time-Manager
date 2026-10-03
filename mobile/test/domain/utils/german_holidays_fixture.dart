import 'package:flutter_work_time/domain/entities/bundesland.dart';
import 'package:flutter_work_time/domain/utils/german_holidays.dart';

/// Von Hand eingetragene Referenzdaten (nicht aus der Implementierung
/// abgeleitet) fuer die Feiertags-Tests. Dient als Vorlage fuer die
/// Web-Fixture: gleiche Erwartungswerte, Format `YYYY-MM-DD` + Feiertags-ID.
///
/// Ostersonntage: 2024-03-31, 2025-04-20, 2026-04-05, 2027-03-28.
const Map<int, Map<GermanHoliday, String>> holidayDatesByYear = {
  2024: {
    GermanHoliday.newYear: '2024-01-01',
    GermanHoliday.goodFriday: '2024-03-29',
    GermanHoliday.easterMonday: '2024-04-01',
    GermanHoliday.labourDay: '2024-05-01',
    GermanHoliday.ascension: '2024-05-09',
    GermanHoliday.whitMonday: '2024-05-20',
    GermanHoliday.germanUnityDay: '2024-10-03',
    GermanHoliday.christmasDay1: '2024-12-25',
    GermanHoliday.christmasDay2: '2024-12-26',
    GermanHoliday.epiphany: '2024-01-06',
    GermanHoliday.corpusChristi: '2024-05-30',
    GermanHoliday.assumption: '2024-08-15',
    GermanHoliday.reformationDay: '2024-10-31',
    GermanHoliday.allSaints: '2024-11-01',
    GermanHoliday.womensDay: '2024-03-08',
    GermanHoliday.worldChildrensDay: '2024-09-20',
    GermanHoliday.repentanceDay: '2024-11-20',
  },
  2025: {
    GermanHoliday.newYear: '2025-01-01',
    GermanHoliday.goodFriday: '2025-04-18',
    GermanHoliday.easterMonday: '2025-04-21',
    GermanHoliday.labourDay: '2025-05-01',
    GermanHoliday.ascension: '2025-05-29',
    GermanHoliday.whitMonday: '2025-06-09',
    GermanHoliday.germanUnityDay: '2025-10-03',
    GermanHoliday.christmasDay1: '2025-12-25',
    GermanHoliday.christmasDay2: '2025-12-26',
    GermanHoliday.epiphany: '2025-01-06',
    GermanHoliday.corpusChristi: '2025-06-19',
    GermanHoliday.assumption: '2025-08-15',
    GermanHoliday.reformationDay: '2025-10-31',
    GermanHoliday.allSaints: '2025-11-01',
    GermanHoliday.womensDay: '2025-03-08',
    GermanHoliday.worldChildrensDay: '2025-09-20',
    GermanHoliday.repentanceDay: '2025-11-19',
  },
  2026: {
    GermanHoliday.newYear: '2026-01-01',
    GermanHoliday.goodFriday: '2026-04-03',
    GermanHoliday.easterMonday: '2026-04-06',
    GermanHoliday.labourDay: '2026-05-01',
    GermanHoliday.ascension: '2026-05-14',
    GermanHoliday.whitMonday: '2026-05-25',
    GermanHoliday.germanUnityDay: '2026-10-03',
    GermanHoliday.christmasDay1: '2026-12-25',
    GermanHoliday.christmasDay2: '2026-12-26',
    GermanHoliday.epiphany: '2026-01-06',
    GermanHoliday.corpusChristi: '2026-06-04',
    GermanHoliday.assumption: '2026-08-15',
    GermanHoliday.reformationDay: '2026-10-31',
    GermanHoliday.allSaints: '2026-11-01',
    GermanHoliday.womensDay: '2026-03-08',
    GermanHoliday.worldChildrensDay: '2026-09-20',
    GermanHoliday.repentanceDay: '2026-11-18',
  },
  2027: {
    GermanHoliday.newYear: '2027-01-01',
    GermanHoliday.goodFriday: '2027-03-26',
    GermanHoliday.easterMonday: '2027-03-29',
    GermanHoliday.labourDay: '2027-05-01',
    GermanHoliday.ascension: '2027-05-06',
    GermanHoliday.whitMonday: '2027-05-17',
    GermanHoliday.germanUnityDay: '2027-10-03',
    GermanHoliday.christmasDay1: '2027-12-25',
    GermanHoliday.christmasDay2: '2027-12-26',
    GermanHoliday.epiphany: '2027-01-06',
    GermanHoliday.corpusChristi: '2027-05-27',
    GermanHoliday.assumption: '2027-08-15',
    GermanHoliday.reformationDay: '2027-10-31',
    GermanHoliday.allSaints: '2027-11-01',
    GermanHoliday.womensDay: '2027-03-08',
    GermanHoliday.worldChildrensDay: '2027-09-20',
    GermanHoliday.repentanceDay: '2027-11-17',
  },
};

/// Bundesweite Feiertage (gelten in allen 16 Laendern).
const List<GermanHoliday> nationwideHolidays = [
  GermanHoliday.newYear,
  GermanHoliday.goodFriday,
  GermanHoliday.easterMonday,
  GermanHoliday.labourDay,
  GermanHoliday.ascension,
  GermanHoliday.whitMonday,
  GermanHoliday.germanUnityDay,
  GermanHoliday.christmasDay1,
  GermanHoliday.christmasDay2,
];

/// Zusaetzliche landesspezifische Feiertage je Bundesland (von Hand).
const Map<Bundesland, List<GermanHoliday>> landSpecificHolidays = {
  Bundesland.badenWuerttemberg: [
    GermanHoliday.epiphany,
    GermanHoliday.corpusChristi,
    GermanHoliday.allSaints,
  ],
  Bundesland.bayern: [
    GermanHoliday.epiphany,
    GermanHoliday.corpusChristi,
    GermanHoliday.assumption,
    GermanHoliday.allSaints,
  ],
  Bundesland.berlin: [GermanHoliday.womensDay],
  Bundesland.brandenburg: [GermanHoliday.reformationDay],
  Bundesland.bremen: [GermanHoliday.reformationDay],
  Bundesland.hamburg: [GermanHoliday.reformationDay],
  Bundesland.hessen: [GermanHoliday.corpusChristi],
  Bundesland.mecklenburgVorpommern: [
    GermanHoliday.womensDay,
    GermanHoliday.reformationDay,
  ],
  Bundesland.niedersachsen: [GermanHoliday.reformationDay],
  Bundesland.nordrheinWestfalen: [
    GermanHoliday.corpusChristi,
    GermanHoliday.allSaints,
  ],
  Bundesland.rheinlandPfalz: [
    GermanHoliday.corpusChristi,
    GermanHoliday.allSaints,
  ],
  Bundesland.saarland: [
    GermanHoliday.corpusChristi,
    GermanHoliday.assumption,
    GermanHoliday.allSaints,
  ],
  Bundesland.sachsen: [
    GermanHoliday.reformationDay,
    GermanHoliday.repentanceDay,
  ],
  Bundesland.sachsenAnhalt: [
    GermanHoliday.epiphany,
    GermanHoliday.reformationDay,
  ],
  Bundesland.schleswigHolstein: [GermanHoliday.reformationDay],
  Bundesland.thueringen: [
    GermanHoliday.worldChildrensDay,
    GermanHoliday.reformationDay,
  ],
};

/// Erwartete Feiertage (`YYYY-MM-DD` -> ID) fuer Jahr und Bundesland.
Map<String, GermanHoliday> expectedHolidays(int year, Bundesland land) {
  final dates = holidayDatesByYear[year]!;
  return {
    for (final id in [...nationwideHolidays, ...landSpecificHolidays[land]!])
      dates[id]!: id,
  };
}

/// ID -> deutscher Name (identisch zu `getGermanHolidayNames`).
const Map<GermanHoliday, String> germanHolidayGermanNames = {
  GermanHoliday.newYear: 'Neujahr',
  GermanHoliday.goodFriday: 'Karfreitag',
  GermanHoliday.easterMonday: 'Ostermontag',
  GermanHoliday.labourDay: 'Tag der Arbeit',
  GermanHoliday.ascension: 'Christi Himmelfahrt',
  GermanHoliday.whitMonday: 'Pfingstmontag',
  GermanHoliday.germanUnityDay: 'Tag der Deutschen Einheit',
  GermanHoliday.christmasDay1: '1. Weihnachtsfeiertag',
  GermanHoliday.christmasDay2: '2. Weihnachtsfeiertag',
  GermanHoliday.epiphany: 'Heilige Drei Könige',
  GermanHoliday.corpusChristi: 'Fronleichnam',
  GermanHoliday.assumption: 'Mariä Himmelfahrt',
  GermanHoliday.reformationDay: 'Reformationstag',
  GermanHoliday.allSaints: 'Allerheiligen',
  GermanHoliday.womensDay: 'Internationaler Frauentag',
  GermanHoliday.worldChildrensDay: 'Weltkindertag',
  GermanHoliday.repentanceDay: 'Buß- und Bettag',
};
