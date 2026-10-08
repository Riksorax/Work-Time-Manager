import '../../domain/utils/german_holidays.dart';
import '../../l10n/app_localizations.dart';

/// Anzeigename eines Feiertags in der App-Sprache (siehe #279).
/// `switch` ohne `default`: neue IDs erzeugen einen Compile-Fehler.
extension GermanHolidayLocalizedName on GermanHoliday {
  String localizedName(AppLocalizations l10n) {
    return switch (this) {
      GermanHoliday.newYear => l10n.holidayNewYear,
      GermanHoliday.goodFriday => l10n.holidayGoodFriday,
      GermanHoliday.easterMonday => l10n.holidayEasterMonday,
      GermanHoliday.labourDay => l10n.holidayLabourDay,
      GermanHoliday.ascension => l10n.holidayAscension,
      GermanHoliday.whitMonday => l10n.holidayWhitMonday,
      GermanHoliday.germanUnityDay => l10n.holidayGermanUnityDay,
      GermanHoliday.christmasDay1 => l10n.holidayChristmasDay1,
      GermanHoliday.christmasDay2 => l10n.holidayChristmasDay2,
      GermanHoliday.epiphany => l10n.holidayEpiphany,
      GermanHoliday.corpusChristi => l10n.holidayCorpusChristi,
      GermanHoliday.assumption => l10n.holidayAssumption,
      GermanHoliday.reformationDay => l10n.holidayReformationDay,
      GermanHoliday.allSaints => l10n.holidayAllSaints,
      GermanHoliday.womensDay => l10n.holidayWomensDay,
      GermanHoliday.worldChildrensDay => l10n.holidayWorldChildrensDay,
      GermanHoliday.repentanceDay => l10n.holidayRepentanceDay,
    };
  }
}
