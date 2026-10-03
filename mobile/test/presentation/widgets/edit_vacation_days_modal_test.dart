import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/entities/settings_entity.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/state/settings_state.dart';
import 'package:flutter_work_time/presentation/view_models/settings_view_model.dart';
import 'package:flutter_work_time/presentation/widgets/edit_vacation_days_modal.dart';

class _FakeSettingsViewModel extends SettingsViewModel {
  final List<int> saved = [];

  @override
  AsyncValue<SettingsState> build() => const AsyncValue.data(SettingsState(
      settings: SettingsEntity(), overtimeBalance: Duration.zero));

  @override
  Future<void> updateVacationDaysPerYear(int days) async => saved.add(days);
}

void main() {
  late _FakeSettingsViewModel fake;

  Future<void> pump(WidgetTester tester, {int current = 30}) async {
    fake = _FakeSettingsViewModel();
    await tester.pumpWidget(ProviderScope(
      overrides: [settingsViewModelProvider.overrideWith(() => fake)],
      child: MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: EditVacationDaysModal(currentDays: current)),
      ),
    ));
  }

  Future<void> enter(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextFormField), text);
    await tester.tap(find.text('Speichern'));
    await tester.pump();
  }

  testWidgets('Vorbelegung', (tester) async {
    await pump(tester, current: 27);
    expect(find.text('27'), findsOneWidget);
  });

  for (final valid in [0, 30, 366]) {
    testWidgets('speichert $valid', (tester) async {
      await pump(tester);
      await enter(tester, '$valid');
      expect(fake.saved, [valid]);
    });
  }

  for (final invalid in ['367', '', 'abc', '999']) {
    testWidgets('lehnt "$invalid" ab', (tester) async {
      await pump(tester);
      await enter(tester, invalid);
      expect(fake.saved, isEmpty);
      expect(find.text('Bitte gib eine ganze Zahl von 0 bis 366 ein.'),
          findsOneWidget);
    });
  }

  testWidgets('digitsOnly filtert Nicht-Ziffern', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextFormField), '3.5a');
    expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        '35');
    await tester.enterText(find.byType(TextFormField), '-1');
    expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        '1');
  });
}
