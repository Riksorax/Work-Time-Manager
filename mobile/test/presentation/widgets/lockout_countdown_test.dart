import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/widgets/lockout_countdown.dart';

void main() {
  Widget subject(Widget child, {Locale locale = const Locale('de')}) =>
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      );

  testWidgets('zeigt den Countdown (DE) und blendet ihn aus der Semantik aus',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(subject(const LockoutNotice(
      remaining: Duration(seconds: 5),
      total: Duration(seconds: 5),
      expired: false,
    )));
    expect(find.text('Zu viele Fehlversuche. Versuche es in 00:05 erneut.'),
        findsOneWidget);
    // Sichtbarer Text hat keine eigene Semantik, nur die Live-Region spricht.
    expect(find.bySemanticsLabel(RegExp(r'00:05')), findsNothing);
    expect(
        find.bySemanticsLabel(
            'Zu viele Fehlversuche. Versuche es in 5 Sekunden erneut.'),
        findsOneWidget);
    handle.dispose();
  });

  testWidgets('EN-Text', (tester) async {
    await tester.pumpWidget(subject(
        const LockoutNotice(
          remaining: Duration(seconds: 65),
          total: Duration(seconds: 65),
          expired: false,
        ),
        locale: const Locale('en')));
    expect(find.text('Too many failed attempts. Try again in 01:05.'),
        findsOneWidget);
  });

  testWidgets('Label ändert sich nicht bei Ticks, nur bei Ablauf',
      (tester) async {
    final handle = tester.ensureSemantics();
    Future<void> show(Duration remaining, bool expired) =>
        tester.pumpWidget(subject(LockoutNotice(
          remaining: remaining,
          total: const Duration(seconds: 5),
          expired: expired,
        )));
    String label() => tester
        .getSemantics(find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.liveRegion == true))
        .label;

    await show(const Duration(seconds: 5), false);
    final start = label();
    await show(const Duration(seconds: 3), false);
    expect(label(), start);
    await show(Duration.zero, true);
    expect(label(), 'Du kannst es jetzt erneut versuchen.');
    handle.dispose();
  });

  testWidgets('ohne Sperre und ohne Ablauf: leeres Label', (tester) async {
    await tester.pumpWidget(subject(const LockoutNotice(
      remaining: Duration.zero,
      total: Duration.zero,
      expired: false,
    )));
    expect(find.textContaining('Fehlversuche'), findsNothing);
  });

  test('lockoutAnnouncement wählt Sekunden oder volle Minuten', () async {
    final de = await AppLocalizations.delegate.load(const Locale('de'));
    expect(lockoutAnnouncement(de, const Duration(seconds: 1)),
        'Zu viele Fehlversuche. Versuche es in einer Sekunde erneut.');
    expect(lockoutAnnouncement(de, const Duration(seconds: 30)),
        'Zu viele Fehlversuche. Versuche es in 30 Sekunden erneut.');
    expect(lockoutAnnouncement(de, const Duration(seconds: 300)),
        'Zu viele Fehlversuche. Versuche es in 5 Minuten erneut.');
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    expect(lockoutAnnouncement(en, const Duration(seconds: 1)),
        'Too many failed attempts. Try again in one second.');
    expect(lockoutAnnouncement(en, const Duration(seconds: 300)),
        'Too many failed attempts. Try again in 5 minutes.');
  });
}
