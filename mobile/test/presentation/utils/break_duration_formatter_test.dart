import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/utils/break_duration_formatter.dart';

// Anzeige der Pausendauer (#504), Deutsch und Englisch.
void main() {
  final de = lookupAppLocalizations(const Locale('de'));
  final en = lookupAppLocalizations(const Locale('en'));

  test('unter einer Minute', () {
    expect(formatBreakDuration(Duration.zero, de), '< 1 Min');
    expect(formatBreakDuration(const Duration(seconds: 59), en), '< 1 min');
  });

  test('volle Minuten, abgerundet', () {
    expect(formatBreakDuration(const Duration(minutes: 30, seconds: 59), de),
        '30 Min');
    expect(formatBreakDuration(const Duration(minutes: 30), en), '30 min');
  });

  test('ab einer Stunde mit Stunden und Minuten', () {
    expect(formatBreakDuration(const Duration(minutes: 65), de), '1 Std 5 Min');
    expect(formatBreakDuration(const Duration(minutes: 65), en), '1 h 5 min');
    expect(formatBreakDuration(const Duration(hours: 1), de), '1 Std 0 Min');
  });

  test('negative Dauer wird wie 0 behandelt', () {
    expect(formatBreakDuration(const Duration(minutes: -5), de), '< 1 Min');
  });
}
