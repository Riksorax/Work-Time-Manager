import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/utils/break_name_localizer.dart';

void main() {
  final de = lookupAppLocalizations(const Locale('de'));
  final en = lookupAppLocalizations(const Locale('en'));

  test('übersetzt Standardnamen in die App-Sprache', () {
    expect(localizedBreakName('Pause', en), 'Break');
    expect(localizedBreakName('Pause 2', en), 'Break 2');
    expect(localizedBreakName('Pause #3', en), 'Break 3');
    expect(localizedBreakName('Automatische Pause', en), 'Automatic break');
    expect(localizedBreakName('Mittagspause', en), 'Lunch break');
    expect(localizedBreakName('Kurzpause', en), 'Short break');
  });

  test('Deutsch bleibt lesbar und normalisiert die Nummerierung', () {
    expect(localizedBreakName('Pause', de), 'Pause');
    expect(localizedBreakName('Pause #3', de), 'Pause 3');
    expect(localizedBreakName('Automatische Pause', de), 'Automatische Pause');
  });

  test('frei vergebene Namen bleiben in jeder Sprache unverändert', () {
    expect(localizedBreakName('Kaffee mit Anna', en), 'Kaffee mit Anna');
    expect(localizedBreakName('Kaffee mit Anna', de), 'Kaffee mit Anna');
  });
}
