import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/core/providers/subscription_provider.dart';
import 'package:flutter_work_time/core/theme/app_theme.dart';
import 'package:flutter_work_time/domain/entities/settings_entity.dart';
import 'package:flutter_work_time/domain/entities/user_entity.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/screens/reports_page.dart';
import 'package:flutter_work_time/presentation/state/monthly_report_state.dart';
import 'package:flutter_work_time/presentation/state/reports_state.dart';
import 'package:flutter_work_time/presentation/state/settings_state.dart';
import 'package:flutter_work_time/presentation/state/weekly_report_state.dart';
import 'package:flutter_work_time/presentation/view_models/reports_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/settings_view_model.dart';

/// #535: Die Aktionszeile von Wochen- und Monats-Tab zeigt bei 412 und
/// 360 px (Handy-Breiten) in de und en alle Buttons in einer Zeile und jede
/// Beschriftung vollständig, ohne „…“.
///
/// Was der Test abdeckt: Er lädt die echte App-Schrift (Roboto aus dem
/// Flutter-SDK, `material_fonts`) und das App-Theme, rendert die Tabs bei
/// Textskalierung 1,0 und prüft je Button-Text
/// `RenderParagraph.didExceedMaxLines` (wird bei einer Kürzung mit „…“
/// `true`). Die Standard-Testschrift wäre dafür ungeeignet (jedes Zeichen
/// 1 em breit). Nicht abgedeckt: größere Systemschrift (dort ist das Kürzen
/// gewollt) und die Schrift-Darstellung eines echten Geräts.
class _StateViewModel extends ReportsViewModel {
  @override
  ReportsState build() => ReportsState(
        isLoading: false,
        focusedDay: DateTime(2026, 10, 9),
        selectedDay: DateTime(2026, 10, 9),
        selectedMonth: DateTime(2026, 10),
        workEntries: const {},
        weeklyReportState: WeeklyReportState(
          workDays: 1,
          dailyWork: {DateTime(2026, 10, 9): const Duration(hours: 8)},
        ),
        monthlyReportState: MonthlyReportState(
          workDays: 1,
          weeklyWork: {41: const Duration(hours: 8)},
          dailyWork: {DateTime(2026, 10, 9): const Duration(hours: 8)},
        ),
      );

  @override
  void loadCurrentMonthData() {}
}

class _Settings extends SettingsViewModel {
  @override
  AsyncValue<SettingsState> build() => const AsyncValue.data(SettingsState(
      settings: SettingsEntity(), overtimeBalance: Duration.zero));
}

/// `material_fonts` des laufenden Flutter-SDK: `flutter_tester` liegt unter
/// `<sdk>/bin/cache/artifacts/engine/<plattform>/`.
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

Future<void> _loadRoboto() async {
  final dir = _materialFonts();
  final loader = FontLoader('Roboto');
  for (final f in [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
  ]) {
    final bytes = File('${dir.path}/$f').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    await _loadRoboto();
    await initializeDateFormatting('de', null);
    await initializeDateFormatting('en', null);
  });

  Future<void> pump(WidgetTester tester, Widget view,
      {required double width, required String locale}) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
      overrides: [
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
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  void expectComplete(WidgetTester tester, List<String> labels) {
    // Alle Buttons in einer Zeile (gleiche Höhe), in der gegebenen Reihenfolge.
    final centers = [for (final l in labels) tester.getCenter(find.text(l))];
    for (var i = 1; i < centers.length; i++) {
      expect(centers[i].dy, centers[0].dy, reason: 'nicht in einer Zeile');
      expect(centers[i].dx, greaterThan(centers[i - 1].dx));
    }
    for (final label in labels) {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
      expect(paragraph.didExceedMaxLines, isFalse,
          reason: '„$label“ ist gekürzt');
    }
  }

  const texts = {
    'de': (
      week: ['Wochen-Reflexion', 'PDF-Export'],
      month: ['PDF-Export', 'Home-Office-PDF'],
    ),
    'en': (
      week: ['Weekly reflection', 'PDF export'],
      month: ['PDF export', 'Home office PDF'],
    ),
  };

  for (final locale in ['de', 'en']) {
    for (final width in [412.0, 360.0]) {
      testWidgets(
          'Wochen-Tab: Aktionen vollständig (${width.toInt()} px, $locale)',
          (tester) async {
        await pump(tester, const WeeklyReportView(),
            width: width, locale: locale);
        expectComplete(tester, texts[locale]!.week);
      });

      testWidgets(
          'Monats-Tab: Aktionen vollständig (${width.toInt()} px, $locale)',
          (tester) async {
        await pump(tester, const MonthlyReportView(),
            width: width, locale: locale);
        expectComplete(tester, texts[locale]!.month);
      });
    }
  }
}
