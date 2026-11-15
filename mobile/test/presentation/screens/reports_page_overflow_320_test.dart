import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:flutter_work_time/core/providers/clock_provider.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/core/providers/subscription_provider.dart';
import 'package:flutter_work_time/core/theme/app_theme.dart';
import 'package:flutter_work_time/domain/entities/break_entity.dart';
import 'package:flutter_work_time/domain/entities/settings_entity.dart';
import 'package:flutter_work_time/domain/entities/user_entity.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/screens/reports_page.dart';
import 'package:flutter_work_time/presentation/state/monthly_report_state.dart';
import 'package:flutter_work_time/presentation/state/reports_state.dart';
import 'package:flutter_work_time/presentation/state/settings_state.dart';
import 'package:flutter_work_time/presentation/view_models/reports_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/settings_view_model.dart';

/// #531 (nebenbei): Auf 320 px liefen mit der echten App-Schrift zwei Zeilen
/// knapp über: im englischen Monats-Tab „Avg. work time per week:“ der
/// Statistikkarte (< 1 px) und im Tages-Tab die Kopfzeile der Eintragskarte
/// (ca. 1,7 px). Die Standard-Testschrift (1 em je Zeichen) zeigt das nicht,
/// deshalb lädt der Test Roboto aus dem Flutter-SDK wie
/// `reports_page_action_row_test`.
final _day = DateTime(2026, 10, 9);

final _entry = WorkEntryEntity(
  id: '2026-10-09',
  date: _day,
  workStart: DateTime(2026, 10, 9, 7, 58),
  workEnd: DateTime(2026, 10, 9, 18, 45),
  breaks: [
    BreakEntity(
        id: 'b',
        name: 'Pause',
        start: DateTime(2026, 10, 9, 12),
        end: DateTime(2026, 10, 9, 12, 45)),
  ],
);

class _StateViewModel extends ReportsViewModel {
  @override
  ReportsState build() => ReportsState(
        isLoading: false,
        focusedDay: _day,
        selectedDay: _day,
        selectedMonth: DateTime(2026, 10),
        workEntries: const {},
        dailyReportState: DailyReportState(
          entries: [_entry],
          workTime: const Duration(hours: 10, minutes: 2),
          breakTime: const Duration(minutes: 45),
          totalTime: const Duration(hours: 10, minutes: 47),
          overtime: const Duration(hours: 2, minutes: 2),
          target: const Duration(hours: 8),
          worked: const Duration(hours: 10, minutes: 2),
        ),
        monthlyReportState: MonthlyReportState(
          workDays: 18,
          totalWorkDuration: const Duration(hours: 168, minutes: 45),
          totalBreakDuration: const Duration(hours: 13, minutes: 30),
          totalNetWorkDuration: const Duration(hours: 155, minutes: 15),
          averageWorkDuration: const Duration(hours: 8, minutes: 37),
          avgWorkDurationPerWeek: const Duration(hours: 38, minutes: 48),
          overtime: const Duration(hours: 11, minutes: 15),
          totalOvertime: const Duration(hours: 123, minutes: 45),
          weeklyWork: {41: const Duration(hours: 40)},
          dailyWork: {_day: const Duration(hours: 10, minutes: 47)},
          // Zeilen netto (#551).
          weeklyNetWork: {41: const Duration(hours: 38)},
          dailyNetWork: {_day: const Duration(hours: 10, minutes: 2)},
        ),
      );

  @override
  void loadCurrentMonthData() {}

  @override
  WorkEntryEntity applyBreakCalculation(WorkEntryEntity entry) => entry;

  @override
  Duration getEffectiveDailyTargetForDate(DateTime date) =>
      const Duration(hours: 8);
}

class _Settings extends SettingsViewModel {
  @override
  AsyncValue<SettingsState> build() => const AsyncValue.data(SettingsState(
      settings: SettingsEntity(), overtimeBalance: Duration.zero));
}

Directory _materialFonts() {
  final candidates = [
    File(Platform.resolvedExecutable).parent.parent.parent.path,
    if (Platform.environment['FLUTTER_ROOT'] != null)
      '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts',
  ];
  for (final c in candidates) {
    final dir = Directory('$c/material_fonts');
    if (File('${dir.path}/Roboto-Regular.ttf').existsSync()) return dir;
  }
  throw StateError('material_fonts nicht gefunden (gesucht: $candidates)');
}

Future<void> _loadFonts() async {
  final dir = _materialFonts();
  final roboto = FontLoader('Roboto');
  for (final f in [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
  ]) {
    final bytes = File('${dir.path}/$f').readAsBytesSync();
    roboto.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await roboto.load();
  final icons = FontLoader('MaterialIcons');
  final bytes = File('${dir.path}/MaterialIcons-Regular.otf').readAsBytesSync();
  icons.addFont(Future.value(ByteData.view(bytes.buffer)));
  await icons.load();
}

void main() {
  setUpAll(() async {
    await _loadFonts();
    await initializeDateFormatting('de', null);
    await initializeDateFormatting('en', null);
  });

  Future<void> pump(WidgetTester tester, Widget view,
      {required String locale}) async {
    tester.view.physicalSize = const Size(320, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 9, 20)),
        authStateProvider
            .overrideWithValue(const AsyncValue.data(UserEntity(id: 'u1'))),
        isPremiumProvider.overrideWithValue(true),
        reportsViewModelProvider.overrideWith(_StateViewModel.new),
        settingsViewModelProvider.overrideWith(_Settings.new),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: view),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  for (final locale in ['de', 'en']) {
    testWidgets('Monats-Tab: Statistikkarte ohne Overflow (320 px, $locale)',
        (tester) async {
      await pump(tester, const MonthlyReportView(), locale: locale);
      expect(
          find.text(locale == 'en'
              ? 'Avg. work time per week:'
              : 'Ø Arbeitszeit pro Woche:'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Tages-Tab: Kopfzeile der Eintragskarte ohne Overflow '
        '(320 px, $locale)', (tester) async {
      await pump(tester, DailyReportView(onEntryTap: (_) {}), locale: locale);
      expect(find.byIcon(Icons.edit), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}
