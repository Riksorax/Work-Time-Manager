import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/utils/leave_balance_utils.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/state/leave_balance_state.dart';
import 'package:flutter_work_time/presentation/view_models/leave_balance_view_model.dart';
import 'package:flutter_work_time/presentation/widgets/leave_balance_card.dart';

class _FakeLeaveViewModel extends LeaveBalanceViewModel {
  _FakeLeaveViewModel(this.initial);
  final LeaveBalanceState initial;
  int reloads = 0;

  @override
  LeaveBalanceState build() => initial;

  @override
  Future<void> reload() async => reloads++;
}

LeaveBalance _balance(int entitlement, int taken, {int sick = 0}) =>
    LeaveBalance(
      year: 2026,
      entitlement: entitlement,
      taken: taken,
      remaining: entitlement - taken,
      sickDays: sick,
    );

void main() {
  Future<_FakeLeaveViewModel> pump(
    WidgetTester tester,
    LeaveBalanceState state, {
    LeaveBalanceCardVariant variant = LeaveBalanceCardVariant.detailed,
    String locale = 'de',
    ThemeData? theme,
  }) async {
    final fake = _FakeLeaveViewModel(state);
    await tester.pumpWidget(ProviderScope(
      overrides: [leaveBalanceViewModelProvider.overrideWith(() => fake)],
      child: MaterialApp(
        theme: theme,
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: LeaveBalanceCard(variant: variant)),
      ),
    ));
    return fake;
  }

  testWidgets('detailed zeigt Rest, Genommen, Anspruch, Kranktage',
      (tester) async {
    await pump(tester, LeaveBalanceState(balance: _balance(30, 12, sick: 3)));
    expect(find.text('Resturlaub'), findsOneWidget);
    expect(find.text('18 von 30 Tagen'), findsOneWidget);
    expect(find.text('Genommen'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Anspruch'), findsOneWidget);
    expect(find.text('Kranktage 2026'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('Ueberschreitung: Text und voller Balken (Plural)',
      (tester) async {
    await pump(tester, LeaveBalanceState(balance: _balance(3, 5)));
    expect(find.text('2 Tage über dem Anspruch'), findsOneWidget);
    final bar = tester
        .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
    expect(bar.value, 1.0);
  });

  testWidgets('Ueberschreitung um genau 1 Tag (Singular)', (tester) async {
    await pump(tester, LeaveBalanceState(balance: _balance(3, 4)));
    expect(find.text('1 Tag über dem Anspruch'), findsOneWidget);
  });

  testWidgets('Anspruch 0: Hinweis, kein Balken', (tester) async {
    await pump(tester, LeaveBalanceState(balance: _balance(0, 0)));
    expect(find.text('Du hast keinen Urlaubsanspruch hinterlegt.'),
        findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('leer: 0 Tage genommen', (tester) async {
    await pump(tester, LeaveBalanceState(balance: _balance(30, 0)));
    expect(find.text('30 von 30 Tagen'), findsOneWidget);
  });

  testWidgets('loading ohne Wert: Spinner', (tester) async {
    await pump(tester, const LeaveBalanceState(isLoading: true));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('loading mit Vorwert: Vorwert bleibt', (tester) async {
    await pump(
        tester, LeaveBalanceState(isLoading: true, balance: _balance(30, 12)));
    expect(find.text('18 von 30 Tagen'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('error: Text und Retry ruft reload', (tester) async {
    final fake = await pump(tester, const LeaveBalanceState(hasError: true));
    expect(find.text('Urlaubsdaten konnten nicht geladen werden.'),
        findsOneWidget);
    await tester.tap(find.text('Erneut versuchen'));
    expect(fake.reloads, 1);
  });

  testWidgets('compact zeigt nur die Rest-Zeile', (tester) async {
    await pump(tester, LeaveBalanceState(balance: _balance(30, 12, sick: 3)),
        variant: LeaveBalanceCardVariant.compact);
    expect(find.text('18 von 30 Tagen'), findsOneWidget);
    expect(find.text('Genommen'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('englische Texte', (tester) async {
    await pump(tester, LeaveBalanceState(balance: _balance(3, 4, sick: 1)),
        locale: 'en');
    expect(find.text('Remaining vacation'), findsOneWidget);
    expect(find.text('1 day over entitlement'), findsOneWidget);
    expect(find.text('Sick days 2026'), findsOneWidget);
  });

  testWidgets('englischer Plural', (tester) async {
    await pump(tester, LeaveBalanceState(balance: _balance(3, 6)),
        locale: 'en');
    expect(find.text('3 days over entitlement'), findsOneWidget);
  });

  testWidgets('Dark Mode: Ueberschreitung nutzt Error-Farbe des Themes',
      (tester) async {
    final theme = ThemeData.dark(useMaterial3: true);
    await pump(tester, LeaveBalanceState(balance: _balance(3, 5)),
        theme: theme);
    final text = tester.widget<Text>(find.text('2 Tage über dem Anspruch'));
    expect(text.style?.color, theme.colorScheme.error);
  });

  testWidgets('Semantics: Fortschrittsbalken traegt die Rest-Aussage',
      (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, LeaveBalanceState(balance: _balance(30, 12)));
    final bar = tester
        .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
    expect(bar.semanticsLabel, '18 von 30 Tagen');
    handle.dispose();
  });
}
