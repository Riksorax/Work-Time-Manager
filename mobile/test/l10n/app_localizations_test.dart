import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';

void main() {
  testWidgets('AppLocalizations resolves English strings when locale is en',
      (tester) async {
    late AppLocalizations l10n;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context);
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(l10n.dashboardTitle, 'Working Time');
    expect(l10n.startTimeTracking, 'Start time tracking');
    expect(l10n.noBreaksYet, 'No breaks recorded yet.');
    expect(l10n.overtimeTotalLabel, 'Total overtime');
    expect(l10n.tabWeekly, 'Weekly');
    expect(l10n.loginButton, 'Sign in');
    expect(l10n.weeklyTargetHoursValue('40.0'), '40.0 h/week');
    expect(l10n.workEntryTypeVacationPlain, 'Vacation');
  });

  testWidgets('AppLocalizations resolves German strings when locale is de',
      (tester) async {
    late AppLocalizations l10n;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context);
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(l10n.dashboardTitle, 'Arbeitszeit');
    expect(l10n.startTimeTracking, 'Zeiterfassung starten');
    expect(l10n.noBreaksYet, 'Noch keine Pausen vorhanden.');
  });
}
