import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/core/providers/subscription_provider.dart';
import 'package:flutter_work_time/domain/entities/user_entity.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/entities/work_profile_entity.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/state/dashboard_state.dart';
import 'package:flutter_work_time/presentation/view_models/dashboard_view_model.dart';
import 'package:flutter_work_time/presentation/widgets/work_profile_switcher.dart';

import 'work_profile_switcher_test.mocks.dart';

/// Dashboard-ViewModel-Fake: feste Werte, kein Timer, kein Repository.
class _FakeDashboard extends DashboardViewModel {
  _FakeDashboard({required this.running, this.stopResult = true, this.log});

  bool running;
  bool stopResult;
  final List<String>? log;
  int buildCount = 0;
  final stopCalls = <String>[];

  @override
  DashboardState build() {
    buildCount++;
    return DashboardState(
        workEntry: WorkEntryEntity(id: 'x', date: DateTime(2026, 10, 5)),
        elapsedTime: Duration.zero);
  }

  @override
  bool get isTimerRunning => running;

  @override
  Future<bool> stopRunningForSwitch(String fromProfileId) async {
    stopCalls.add(fromProfileId);
    log?.add('stop');
    return stopResult;
  }
}

// Guard beim Profilwechsel mit laufendem Timer (#388, PR 2).
void main() {
  late MockWorkProfileRepository mockRepository;
  late SharedPreferences prefs;
  late List<String> log;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    log = [];
    mockRepository = MockWorkProfileRepository();
    when(mockRepository.getAdditionalProfiles()).thenAnswer(
        (_) async => [const WorkProfileEntity(id: 'p1', name: 'Zweitjob')]);
  });

  Widget subject(_FakeDashboard fake, {Locale locale = const Locale('de')}) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authStateProvider.overrideWithValue(
          const AsyncValue.data(UserEntity(id: '1', email: 'test@test.com')),
        ),
        workProfileRepositoryProvider.overrideWithValue(mockRepository),
        isPremiumProvider.overrideWithValue(true),
        dashboardViewModelProvider.overrideWith(() => fake),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(appBar: AppBar(actions: const [WorkProfileSwitcher()])),
      ),
    );
  }

  Future<void> pumpIt(WidgetTester tester, _FakeDashboard fake,
      {Locale locale = const Locale('de')}) async {
    await tester.pumpWidget(subject(fake, locale: locale));
    await tester.pumpAndSettle();
  }

  String? active(WidgetTester tester) => ProviderScope.containerOf(
          tester.element(find.byType(WorkProfileSwitcher)))
      .read(activeWorkProfileIdProvider);

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String name) async {
    await openMenu(tester);
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
  }

  Future<void> startAdd(WidgetTester tester, String name) async {
    await openMenu(tester);
    await tester.tap(find.text('Neues Profil'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), name);
    await tester.tap(find.text('Anlegen'));
    // Kein pumpAndSettle: der Anlegen-Dialog zeigt währenddessen einen
    // Spinner (_isSaving), dessen Animation nie zur Ruhe kommt.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  group('Wechsler', () {
    testWidgets('W1 kein Timer: kein Dialog, Wechsel sofort', (tester) async {
      final fake = _FakeDashboard(running: false);
      await pumpIt(tester, fake);
      await choose(tester, 'Zweitjob');

      expect(find.text('Zeiterfassung läuft'), findsNothing);
      expect(active(tester), 'p1');
      expect(fake.stopCalls, isEmpty);
    });

    testWidgets('W2 Timer läuft, Abbrechen: Dialog, kein Wechsel',
        (tester) async {
      final fake = _FakeDashboard(running: true);
      await pumpIt(tester, fake);
      await choose(tester, 'Zweitjob');

      expect(find.text('Zeiterfassung läuft'), findsOneWidget);
      expect(
          find.text('Im Profil "Standard" läuft noch eine Zeiterfassung. '
              'Sie wird beendet und gespeichert, bevor du in das Profil '
              '"Zweitjob" wechselst.'),
          findsOneWidget);
      expect(find.text('Abbrechen'), findsOneWidget);
      expect(find.text('Beenden und wechseln'), findsOneWidget);

      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(active(tester), isNull);
      expect(fake.stopCalls, isEmpty);
    });

    testWidgets('W3 Bestätigen: Stop mit from-ID, danach Wechsel',
        (tester) async {
      final fake = _FakeDashboard(running: true);
      await pumpIt(tester, fake);
      await choose(tester, 'Zweitjob');
      await tester.tap(find.text('Beenden und wechseln'));
      await tester.pumpAndSettle();

      expect(fake.stopCalls, ['default']);
      expect(active(tester), 'p1');
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('W4 Stop scheitert: kein Wechsel, Snackbar', (tester) async {
      final fake = _FakeDashboard(running: true, stopResult: false);
      await pumpIt(tester, fake);
      await choose(tester, 'Zweitjob');
      await tester.tap(find.text('Beenden und wechseln'));
      await tester.pumpAndSettle();

      expect(fake.stopCalls, ['default']);
      expect(active(tester), isNull);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.textContaining('Speichern fehlgeschlagen'), findsOneWidget);
    });

    testWidgets('W5 aktives Profil erneut wählen: nichts passiert',
        (tester) async {
      final fake = _FakeDashboard(running: true);
      await pumpIt(tester, fake);
      await choose(tester, 'Standard');

      expect(find.byType(AlertDialog), findsNothing);
      expect(fake.stopCalls, isEmpty);
      expect(active(tester), isNull);
    });

    testWidgets('W7 Settings-Tab: VM wird per ref.read gebaut und fragt',
        (tester) async {
      final fake = _FakeDashboard(running: true);
      await pumpIt(tester, fake);
      expect(fake.buildCount, 0);
      await choose(tester, 'Zweitjob');

      expect(fake.buildCount, greaterThan(0));
      expect(find.text('Zeiterfassung läuft'), findsOneWidget);
    });

    testWidgets('W12 englische Texte', (tester) async {
      final fake = _FakeDashboard(running: true);
      await pumpIt(tester, fake, locale: const Locale('en'));
      await openMenu(tester);
      await tester.tap(find.text('Zweitjob'));
      await tester.pumpAndSettle();

      expect(find.text('Time tracking is running'), findsOneWidget);
      expect(
          find.text('Time tracking is still running in profile "Standard". '
              'It will be stopped and saved before you switch to profile '
              '"Zweitjob".'),
          findsOneWidget);
      expect(find.text('Stop and switch'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });
  });

  group('Neues Profil', () {
    // Ohne zusätzliches Profil, sonst ist das Limit erreicht.
    setUp(() => when(mockRepository.getAdditionalProfiles())
        .thenAnswer((_) async => []));

    testWidgets('W8 kein Timer: Anlegen wie bisher', (tester) async {
      when(mockRepository.addProfile('Neu')).thenAnswer(
          (_) async => const WorkProfileEntity(id: 'p2', name: 'Neu'));
      final fake = _FakeDashboard(running: false);
      await pumpIt(tester, fake);
      await startAdd(tester, 'Neu');

      verify(mockRepository.addProfile('Neu')).called(1);
      expect(find.text('Zeiterfassung läuft'), findsNothing);
      expect(active(tester), 'p2');
    });

    testWidgets('W9 Timer läuft, Abbrechen: kein API-Aufruf, Dialog bleibt',
        (tester) async {
      final fake = _FakeDashboard(running: true);
      await pumpIt(tester, fake);
      await startAdd(tester, 'Neu');

      expect(find.text('Zeiterfassung läuft'), findsOneWidget);
      expect(find.textContaining('"Neu"'), findsOneWidget);
      await tester.tap(find.text('Abbrechen').last);
      await tester.pumpAndSettle();

      verifyNever(mockRepository.addProfile(any));
      expect(active(tester), isNull);
      expect(find.text('Zeiterfassung läuft'), findsNothing);
      // Anlegen-Dialog bleibt mit dem Namen offen, Button wieder aktiv.
      expect(find.widgetWithText(TextField, 'Neu'), findsOneWidget);
      expect(
          tester
              .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Anlegen'))
              .onPressed,
          isNotNull);
    });

    testWidgets('W10 Bestätigen: Reihenfolge Stop, addProfile, Wechsel',
        (tester) async {
      when(mockRepository.addProfile('Neu')).thenAnswer((_) async {
        log.add('add');
        return const WorkProfileEntity(id: 'p2', name: 'Neu');
      });
      final fake = _FakeDashboard(running: true, log: log);
      await pumpIt(tester, fake);
      await startAdd(tester, 'Neu');
      await tester.tap(find.text('Beenden und wechseln'));
      await tester.pumpAndSettle();

      expect(log, ['stop', 'add']);
      expect(fake.stopCalls, ['default']);
      expect(active(tester), 'p2');
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('W11 Stop scheitert: kein addProfile, Snackbar, Dialog offen',
        (tester) async {
      final fake = _FakeDashboard(running: true, stopResult: false);
      await pumpIt(tester, fake);
      await startAdd(tester, 'Neu');
      await tester.tap(find.text('Beenden und wechseln'));
      await tester.pumpAndSettle();

      verifyNever(mockRepository.addProfile(any));
      expect(active(tester), isNull);
      expect(find.textContaining('Speichern fehlgeschlagen'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Neu'), findsOneWidget);
      expect(
          tester
              .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Anlegen'))
              .onPressed,
          isNotNull);
    });
  });

  testWidgets('W13 Löschen des aktiven Profils: kein Bestätigungsdialog',
      (tester) async {
    when(mockRepository.deleteProfile('p1')).thenAnswer((_) async {});
    final fake = _FakeDashboard(running: true);
    await pumpIt(tester, fake);
    await ProviderScope.containerOf(
            tester.element(find.byType(WorkProfileSwitcher)))
        .read(activeWorkProfileIdProvider.notifier)
        .setActiveProfile('p1');
    await tester.pumpAndSettle();

    await openMenu(tester);
    await tester.tap(find.text('Profile verwalten'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Profil löschen?'), findsOneWidget);
    await tester.tap(find.text('Löschen'));
    await tester.pumpAndSettle();

    verify(mockRepository.deleteProfile('p1')).called(1);
    expect(find.text('Zeiterfassung läuft'), findsNothing);
    expect(fake.stopCalls, isEmpty);
    expect(active(tester), isNull);
  });
}
