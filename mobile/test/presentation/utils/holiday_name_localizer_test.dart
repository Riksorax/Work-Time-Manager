import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/utils/german_holidays.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/utils/holiday_name_localizer.dart';

import '../../domain/utils/german_holidays_fixture.dart';

void main() {
  final de = lookupAppLocalizations(const Locale('de'));
  final en = lookupAppLocalizations(const Locale('en'));

  const englishNames = {
    GermanHoliday.newYear: "New Year's Day",
    GermanHoliday.goodFriday: 'Good Friday',
    GermanHoliday.easterMonday: 'Easter Monday',
    GermanHoliday.labourDay: 'Labour Day',
    GermanHoliday.ascension: 'Ascension Day',
    GermanHoliday.whitMonday: 'Whit Monday',
    GermanHoliday.germanUnityDay: 'German Unity Day',
    GermanHoliday.christmasDay1: 'Christmas Day',
    GermanHoliday.christmasDay2: "Boxing Day (St. Stephen's Day)",
    GermanHoliday.epiphany: 'Epiphany',
    GermanHoliday.corpusChristi: 'Corpus Christi',
    GermanHoliday.assumption: 'Assumption Day',
    GermanHoliday.reformationDay: 'Reformation Day',
    GermanHoliday.allSaints: "All Saints' Day",
    GermanHoliday.womensDay: "International Women's Day",
    GermanHoliday.worldChildrensDay: "World Children's Day",
    GermanHoliday.repentanceDay: 'Repentance and Prayer Day',
  };

  test('deckt alle IDs ab', () {
    expect(englishNames.keys.toSet(), GermanHoliday.values.toSet());
  });

  for (final id in GermanHoliday.values) {
    test('${id.name} de/en', () {
      expect(id.localizedName(de), germanHolidayGermanNames[id]);
      expect(id.localizedName(en), englishNames[id]);
    });
  }
}
