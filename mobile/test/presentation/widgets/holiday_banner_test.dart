import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/providers/clock_provider.dart';
import 'package:flutter_work_time/domain/entities/bundesland.dart';
import 'package:flutter_work_time/domain/entities/settings_entity.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/state/settings_state.dart';
import 'package:flutter_work_time/presentation/view_models/settings_view_model.dart';
import 'package:flutter_work_time/presentation/widgets/holiday_banner.dart';

Bundesland? _land;

class _FakeSettings extends SettingsViewModel {
  @override
  AsyncValue<SettingsState> build() => AsyncValue.data(SettingsState(
        settings: SettingsEntity(bundesland: _land),
        overtimeBalance: Duration.zero,
      ));
}

void main() {
  late DateTime now;

  setUp(() {
    _land = Bundesland.bayern;
    now = DateTime(2026, 10, 3, 12);
  });

  Future<void> pump(WidgetTester tester,
      {String locale = 'de', double? textScale}) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        settingsViewModelProvider.overrideWith(_FakeSettings.new),
        clockProvider.overrideWithValue(() => now),
      ],
      child: MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: textScale == null
            ? null
            : (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(textScale)),
                  child: child!,
                ),
        home: const Scaffold(body: HolidayBanner()),
      ),
    ));
    await tester.pump();
  }

  testWidgets('zeigt deutschen Text', (tester) async {
    await pump(tester);
    expect(find.text('Heute ist Feiertag: Tag der Deutschen Einheit'),
        findsOneWidget);
  });

  testWidgets('zeigt englischen Text', (tester) async {
    await pump(tester, locale: 'en');
    expect(find.text('Today is a public holiday: German Unity Day'),
        findsOneWidget);
  });

  testWidgets('kein Feiertag -> nichts, keine Semantics', (tester) async {
    now = DateTime(2026, 10, 4, 12);
    final handle = tester.ensureSemantics();
    await pump(tester);
    expect(find.textContaining('Feiertag'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('Feiertag')), findsNothing);
    handle.dispose();
  });

  testWidgets('kein Bundesland -> nichts', (tester) async {
    _land = null;
    await pump(tester);
    expect(find.textContaining('Feiertag'), findsNothing);
  });

  testWidgets('Mitternacht schaltet Banner um und plant neu', (tester) async {
    now = DateTime(2026, 10, 2, 23, 59, 30);
    await pump(tester);
    expect(find.textContaining('Feiertag'), findsNothing);

    now = DateTime(2026, 10, 3, 0, 0, 1);
    await tester.pump(const Duration(seconds: 31));
    await tester.pump();
    expect(find.text('Heute ist Feiertag: Tag der Deutschen Einheit'),
        findsOneWidget);

    // Zweiter Wechsel 3.10. -> 4.10.: Timer wurde neu geplant.
    now = DateTime(2026, 10, 4, 0, 0, 1);
    await tester.pump(const Duration(hours: 24));
    await tester.pump();
    expect(find.textContaining('Feiertag'), findsNothing);
  });

  testWidgets('Resume aktualisiert das Banner', (tester) async {
    now = DateTime(2026, 10, 2, 12);
    await pump(tester);
    expect(find.textContaining('Feiertag'), findsNothing);

    now = DateTime(2026, 10, 3, 12);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.textContaining('Feiertag'), findsOneWidget);
  });

  testWidgets('Dispose raeumt Timer auf', (tester) async {
    await pump(tester);
    await tester.pumpWidget(const SizedBox());
    // Kein Pending-Timer-Fehler am Testende.
  });

  testWidgets('langer EN-Name laeuft bei schmaler Breite nicht ueber',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    _land = Bundesland.sachsen;
    now = DateTime(2026, 11, 18, 10);
    await pump(tester, locale: 'en', textScale: 2.0);
    expect(find.text('Today is a public holiday: Repentance and Prayer Day'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Semantics: Label, liveRegion, Container', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester);
    final finder =
        find.bySemanticsLabel('Heute ist Feiertag: Tag der Deutschen Einheit');
    expect(finder, findsOneWidget);
    final data = tester.getSemantics(finder).getSemanticsData();
    expect(data.flagsCollection.isLiveRegion, isTrue);
    handle.dispose();
  });
}
