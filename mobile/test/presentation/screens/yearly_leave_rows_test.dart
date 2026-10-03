import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/utils/leave_balance_utils.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/screens/reports_page.dart';
import 'package:flutter_work_time/presentation/state/leave_balance_state.dart';
import 'package:flutter_work_time/presentation/view_models/leave_balance_view_model.dart';

class _FakeLeaveViewModel extends LeaveBalanceViewModel {
  @override
  LeaveBalanceState build() => const LeaveBalanceState(
        balance: LeaveBalance(
            year: 2026, entitlement: 30, taken: 12, remaining: 18, sickDays: 0),
      );
}

void main() {
  Future<void> pump(WidgetTester tester, int year) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        leaveBalanceViewModelProvider.overrideWith(_FakeLeaveViewModel.new),
        leaveBalanceNowProvider
            .overrideWith((ref) => () => DateTime(2026, 6, 1)),
      ],
      child: MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: YearlyLeaveRows(year: year)),
      ),
    ));
  }

  testWidgets('laufendes Jahr zeigt Anspruch und Resturlaub', (tester) async {
    await pump(tester, 2026);
    expect(find.text('Anspruch'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    expect(find.text('Resturlaub'), findsOneWidget);
    expect(find.text('18'), findsOneWidget);
  });

  testWidgets('Vorjahr zeigt Hinweis statt Rest', (tester) async {
    await pump(tester, 2025);
    expect(
        find.text('Der Resturlaub wird nur für das laufende Jahr angezeigt.'),
        findsOneWidget);
    expect(find.text('Resturlaub'), findsNothing);
  });
}
