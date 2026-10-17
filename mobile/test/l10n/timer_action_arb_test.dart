import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';

// Texte der Timer-Aktionen (#274): Notification-Buttons und App-Shortcuts.
void main() {
  test('timerActionStart/Stop in Deutsch', () {
    final l10n = lookupAppLocalizations(const Locale('de'));
    expect(l10n.timerActionStart, 'Einstempeln');
    expect(l10n.timerActionStop, 'Ausstempeln');
  });

  test('timerActionStart/Stop in Englisch', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(l10n.timerActionStart, 'Clock in');
    expect(l10n.timerActionStop, 'Clock out');
  });
}
