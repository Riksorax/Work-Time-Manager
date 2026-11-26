import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:logger/logger.dart';
import 'package:printing/src/interface.dart' show PrintingPlatform;

import 'package:flutter_work_time/core/providers/clock_provider.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/core/providers/subscription_provider.dart';
import 'package:flutter_work_time/core/services/pdf_report_service.dart';
import 'package:flutter_work_time/core/theme/app_theme.dart';
import 'package:flutter_work_time/core/utils/api_errors.dart';
import 'package:flutter_work_time/data/datasources/remote/api_client.dart';
import 'package:flutter_work_time/data/models/yearly_leave_report_model.dart';
import 'package:flutter_work_time/domain/entities/settings_entity.dart';
import 'package:flutter_work_time/domain/entities/user_entity.dart';
import 'package:flutter_work_time/domain/entities/work_profile_entity.dart';
import 'package:flutter_work_time/domain/entities/yearly_leave_report.dart';
import 'package:flutter_work_time/domain/utils/yearly_report_utils.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/screens/reports_page.dart';
import 'package:flutter_work_time/presentation/state/settings_state.dart';
import 'package:flutter_work_time/presentation/state/yearly_report_state.dart';
import 'package:flutter_work_time/presentation/view_models/settings_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/yearly_comparison_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/yearly_report_view_model.dart';

import '../../support/fake_printing_platform.dart';
import '../../support/reported_logs.dart';
import '../../support/yearly_comparison_fixture.dart';
import '../../support/yearly_leave_report_fixture.dart';

/// #284: Urlaubs- und Krankheitsauswertung als PDF im Jahres-Tab. Die drei
/// PDF-Auswertungen liegen im Menü des Buttons „PDF-Export“.

class _Settings extends SettingsViewModel {
  @override
  AsyncValue<SettingsState> build() => const AsyncValue.data(SettingsState(
      settings: SettingsEntity(), overtimeBalance: Duration.zero));
}

class _Yearly extends YearlyReportViewModel {
  _Yearly(this.year, {this.hasError = false});
  final int year;
  final bool hasError;

  @override
  YearlyReportState build() => YearlyReportState(
        year: year,
        hasError: hasError,
        months: List.generate(12, (i) => MonthSummary.empty(i + 1)),
      );

  @override
  Future<void> loadYear(int year) async {}
}

class _Profile extends ActiveWorkProfileIdNotifier {
  _Profile(this.id);
  final String? id;

  @override
  String? build() => id;
}

/// Beantwortet nur die Urlaubsauswertung; zeichnet die Aufrufe auf.
class _LeaveApi extends Fake implements ApiClient {
  _LeaveApi(this.handler);
  Future<Map<String, dynamic>> Function(int year) handler;
  final calls = <({int year, String? profileId})>[];

  @override
  Future<YearlyLeaveReport> getYearlyLeaveReport(int year,
      {String? profileId}) async {
    calls.add((year: year, profileId: profileId));
    return yearlyLeaveReportFromJson(await handler(year), requestedYear: year);
  }
}

/// Echter Service (PDF über [FakePrintingPlatform]), merkt sich die Argumente.
class _RecordingPdfService extends PdfReportService {
  ({
    YearlyLeaveReport report,
    bool isCurrentYear,
    DateTime createdOn,
    String? profileName,
    String locale,
  })? last;

  @override
  Future<void> exportLeaveReport({
    required AppLocalizations l10n,
    required String locale,
    required YearlyLeaveReport report,
    required bool isCurrentYear,
    required DateTime createdOn,
    String? profileName,
  }) {
    last = (
      report: report,
      isCurrentYear: isCurrentYear,
      createdOn: createdOn,
      profileName: profileName,
      locale: locale,
    );
    return super.exportLeaveReport(
      l10n: l10n,
      locale: locale,
      report: report,
      isCurrentYear: isCurrentYear,
      createdOn: createdOn,
      profileName: profileName,
    );
  }
}

/// `material_fonts` des laufenden Flutter-SDK (wie
/// `reports_page_action_row_test`): mit der echten Schrift prüft der
/// Overflow-Test die wirklichen Textbreiten.
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

const _user = UserEntity(id: 'u1', email: 'a@b.c');

void main() {
  setUpAll(() async {
    await _loadRoboto();
    await initializeDateFormatting('de', null);
    await initializeDateFormatting('en', null);
  });

  final logs = <LogEvent>[];
  captureLogs(logs);

  late FakePrintingPlatform platform;
  late _LeaveApi api;
  late _RecordingPdfService service;

  setUp(() {
    platform = FakePrintingPlatform();
    PrintingPlatform.instance = platform;
    api = _LeaveApi((year) async => yearlyLeaveReportJson(year));
    service = _RecordingPdfService();
  });

  Future<void> pumpView(
    WidgetTester tester, {
    int year = 2026,
    bool hasError = false,
    String locale = 'de',
    double width = 412,
    String? profileId,
    Future<List<WorkProfileEntity>> Function()? profiles,
  }) async {
    tester.view.physicalSize = Size(width, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // „Heute“ fest: 15.11.2026 (laufendes Jahr 2026).
          clockProvider.overrideWithValue(() => DateTime(2026, 11, 15, 10)),
          authStateProvider
              .overrideWithValue(const AsyncValue<UserEntity?>.data(_user)),
          isPremiumProvider.overrideWithValue(true),
          apiClientProvider.overrideWithValue(api),
          pdfReportServiceProvider.overrideWithValue(service),
          activeWorkProfileIdProvider.overrideWith(() => _Profile(profileId)),
          workProfilesProvider.overrideWith((ref) =>
              profiles?.call() ??
              Future.value([WorkProfileEntity.defaultProfile()])),
          settingsViewModelProvider.overrideWith(_Settings.new),
          yearlyReportViewModelProvider
              .overrideWith(() => _Yearly(year, hasError: hasError)),
          yearlyComparisonViewModelProvider
              .overrideWith(FakeYearlyComparisonViewModel.new),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: YearlyReportView()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  /// Öffnet das Menü. Kein `pumpAndSettle`: die Vergleichskarte zeigt einen
  /// endlosen Ladeindikator.
  Future<void> openMenu(WidgetTester tester,
      {String label = 'PDF-Export'}) async {
    await tester.tap(find.text(label));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Wählt den Menüeintrag und wartet (echte Zeit), bis der Export fertig ist.
  Future<void> chooseAndWait(WidgetTester tester, String item,
      {required bool Function() done}) async {
    await tester.tap(find.text(item));
    await tester.runAsync(() async {
      for (var i = 0; i < 200 && !done(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('Menü zeigt die drei Auswertungen', (tester) async {
    await pumpView(tester);
    expect(find.text('Jahresbericht (PDF)'), findsNothing);
    expect(find.byTooltip('PDF-Auswertung wählen'), findsOneWidget);

    await openMenu(tester);
    expect(find.text('Jahresbericht (PDF)'), findsOneWidget);
    expect(find.text('Home-Office-Auswertung (PDF)'), findsOneWidget);
    expect(find.text('Urlaub und Krankheit (PDF)'), findsOneWidget);
  });

  testWidgets('Urlaub/Krank: lädt das gewählte Jahr und exportiert',
      (tester) async {
    await pumpView(tester);
    await openMenu(tester);
    await chooseAndWait(tester, 'Urlaub und Krankheit (PDF)',
        done: () => platform.lastFilename != null);

    expect(api.calls, [(year: 2026, profileId: null)]);
    expect(platform.lastFilename, 'Urlaub-Krank-Auswertung_2026.pdf');
    expect(String.fromCharCodes(platform.lastBytes!.take(4)), '%PDF');
    expect(service.last!.isCurrentYear, isTrue);
    expect(service.last!.createdOn, DateTime(2026, 11, 15));
    expect(service.last!.profileName, isNull);
    expect(service.last!.report.vacationDaysTaken, 14);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('vergangenes Jahr: nicht das laufende Jahr', (tester) async {
    await pumpView(tester, year: 2025);
    await openMenu(tester);
    await chooseAndWait(tester, 'Urlaub und Krankheit (PDF)',
        done: () => platform.lastFilename != null);

    expect(api.calls.single.year, 2025);
    expect(platform.lastFilename, 'Urlaub-Krank-Auswertung_2025.pdf');
    expect(service.last!.isCurrentYear, isFalse);
  });

  testWidgets('leeres Jahr: PDF wird trotzdem erzeugt', (tester) async {
    api.handler = (year) async => yearlyLeaveReportJson(year, empty: true);
    await pumpView(tester);
    await openMenu(tester);
    await chooseAndWait(tester, 'Urlaub und Krankheit (PDF)',
        done: () => platform.lastFilename != null);

    expect(platform.lastFilename, 'Urlaub-Krank-Auswertung_2026.pdf');
    expect(service.last!.report.isEmpty, isTrue);
  });

  testWidgets('Zusatzprofil: profileId an die API, Name ins PDF',
      (tester) async {
    await pumpView(tester,
        profileId: 'p1',
        profiles: () async => [
              WorkProfileEntity.defaultProfile(),
              const WorkProfileEntity(id: 'p1', name: 'Nebenjob'),
            ]);
    await openMenu(tester);
    await chooseAndWait(tester, 'Urlaub und Krankheit (PDF)',
        done: () => platform.lastFilename != null);

    expect(api.calls, [(year: 2026, profileId: 'p1')]);
    expect(service.last!.profileName, 'Nebenjob');
  });

  testWidgets('Profil-Liste nicht ladbar: PDF ohne Profilnamen',
      (tester) async {
    await pumpView(tester,
        profileId: 'p1', profiles: () async => throw Exception('offline'));
    await openMenu(tester);
    await tester.tap(find.text('Urlaub und Krankheit (PDF)'));
    // Riverpod versucht den Provider neu, `.future` wartet: das Zeitlimit
    // (3 s, Testuhr) beendet das Warten, danach geht es ohne Namen weiter.
    // Der Menüeintrag löst erst im nächsten Frame aus.
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(api.calls, isEmpty);
    await tester.pump(const Duration(seconds: 2));
    await tester.runAsync(() async {
      for (var i = 0; i < 200 && platform.lastFilename == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
    });
    await tester.pump();

    expect(platform.lastFilename, 'Urlaub-Krank-Auswertung_2026.pdf');
    expect(api.calls.single.profileId, 'p1');
    expect(service.last!.profileName, isNull);
  });

  testWidgets('Ladefehler: rote Snackbar, kein PDF, an Crashlytics',
      (tester) async {
    api.handler = (_) async => throw const ApiException('x', 500);
    await pumpView(tester);
    await openMenu(tester);
    await chooseAndWait(tester, 'Urlaub und Krankheit (PDF)',
        done: () => api.calls.isNotEmpty);

    expect(platform.lastFilename, isNull);
    expect(service.last, isNull);
    // Verständliche Meldung ohne Ausnahmetext (#582).
    expect(
        find.text('Der PDF-Export ist fehlgeschlagen. Bitte versuche es '
            'erneut.'),
        findsOneWidget);
    expect(find.textContaining('ApiException'), findsNothing);
    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.backgroundColor, Colors.red);
    expect(reported(logs, 'Urlaubsauswertung'), hasLength(1));
    expect(tester.takeException(), isNull);
  });

  for (final entry in transientNetworkErrors.entries) {
    testWidgets('Netzwerkfehler ${entry.key}: Snackbar, kein logger.e',
        (tester) async {
      api.handler = (_) async => throw entry.value;
      await pumpView(tester);
      await openMenu(tester);
      await chooseAndWait(tester, 'Urlaub und Krankheit (PDF)',
          done: () => api.calls.isNotEmpty);

      expect(platform.lastFilename, isNull);
      // Netzwerkfehler: „Keine Verbindung …“ ohne Ausnahmetext (#582).
      expect(find.textContaining('Keine Verbindung.'), findsOneWidget);
      expect(find.textContaining('Exception'), findsNothing);
      expect(reported(logs, 'Urlaubsauswertung'), isEmpty);
    });
  }

  testWidgets('Fehlerzustand der Jahreswerte: kein Export-Button',
      (tester) async {
    await pumpView(tester, hasError: true);
    expect(find.text('PDF-Export'), findsNothing);
    expect(find.byIcon(Icons.picture_as_pdf_outlined), findsNothing);
  });

  testWidgets('Englisch: Beschriftung und Menü', (tester) async {
    await pumpView(tester, locale: 'en');
    expect(find.byTooltip('Choose a PDF report'), findsOneWidget);
    await openMenu(tester, label: 'PDF export');
    expect(find.text('Yearly report (PDF)'), findsOneWidget);
    expect(find.text('Home office report (PDF)'), findsOneWidget);
    expect(find.text('Vacation and sick days (PDF)'), findsOneWidget);
    await chooseAndWait(tester, 'Vacation and sick days (PDF)',
        done: () => platform.lastFilename != null);
    // Dateiname fest deutsch.
    expect(platform.lastFilename, 'Urlaub-Krank-Auswertung_2026.pdf');
    expect(service.last!.locale, 'en');
  });

  for (final locale in ['de', 'en']) {
    for (final width in [320.0, 360.0, 412.0]) {
      testWidgets(
          'kein Overflow, Texte vollständig (${width.toInt()} px, $locale)',
          (tester) async {
        await pumpView(tester, locale: locale, width: width);
        expect(tester.takeException(), isNull);
        final label = locale == 'de' ? 'PDF-Export' : 'PDF export';
        expect(
            tester
                .renderObject<RenderParagraph>(find.text(label))
                .didExceedMaxLines,
            isFalse);

        await openMenu(tester, label: label);
        expect(tester.takeException(), isNull);
        final items = locale == 'de'
            ? [
                'Jahresbericht (PDF)',
                'Home-Office-Auswertung (PDF)',
                'Urlaub und Krankheit (PDF)',
              ]
            : [
                'Yearly report (PDF)',
                'Home office report (PDF)',
                'Vacation and sick days (PDF)',
              ];
        for (final item in items) {
          final rect = tester.getRect(find.text(item));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(width), reason: item);
          expect(
              tester
                  .renderObject<RenderParagraph>(find.text(item))
                  .didExceedMaxLines,
              isFalse,
              reason: '„$item“ ist gekürzt');
        }
      });
    }
  }
}
