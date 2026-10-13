import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/domain/services/review_requester.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../support/dashboard_harness.dart';
import '../../support/fake_review_prompt_repository.dart';
import 'dashboard_view_model_review_test.mocks.dart';

// Einmalige Bewertungsanfrage nach dem Beenden eines Arbeitstags. Feste Daten:
// Mo 2026-10-05, Uhr 17:00, Timer läuft ab 08:00; vier abgeschlossene Tage
// davor (29.09.-02.10.) plus der heutige ergeben die fünf nötigen Tage. Die
// Erstnutzung (28.09.) liegt genau 7 Tage zurück.
@GenerateMocks([ReviewRequester])
void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  final mo = DateTime(2026, 10, 5);
  DateTime at(int h, [int m = 0]) => DateTime(2026, 10, 5, h, m);

  late MockReviewRequester requester;
  late FakeReviewPromptRepository prompts;
  late bool promptedWhenRequested;

  void seedPast(Harness h, {bool runningToday = true}) {
    for (final day in [
      DateTime(2026, 9, 29),
      DateTime(2026, 9, 30),
      DateTime(2026, 10, 1),
      DateTime(2026, 10, 2),
    ]) {
      h.seed(entryOf(day,
          start: DateTime(day.year, day.month, day.day, 8),
          end: DateTime(day.year, day.month, day.day, 16)));
    }
    if (runningToday) h.seed(entryOf(mo, start: at(8)));
    h.overtime.stored = const Duration(minutes: 120);
  }

  /// Wie `scenario`, aber mit gemockter Review-Abstraktion und lokalem Zustand.
  void reviewScenario(
    String name,
    void Function(Harness h) body, {
    bool available = true,
    DateTime? firstUse,
    bool prompted = false,
    bool runningToday = true,
  }) {
    scenario(
      name,
      at(17),
      (h) {
        h.boot();
        body(h);
      },
      setUp: (h) {
        // Frische Doubles je Szenario (der Provider wird nur gebaut, wenn das
        // ViewModel sie tatsächlich liest).
        requester = MockReviewRequester();
        promptedWhenRequested = false;
        when(requester.isAvailable()).thenAnswer((_) async => available);
        when(requester.requestReview()).thenAnswer((_) async {
          promptedWhenRequested = prompts.prompted;
        });
        prompts = FakeReviewPromptRepository(
            firstUse: firstUse ?? DateTime(2026, 9, 28), prompted: prompted);
        seedPast(h, runningToday: runningToday);
      },
      overrides: [
        reviewRequesterProvider.overrideWith((ref) => requester),
        reviewPromptRepositoryProvider.overrideWith((ref) => prompts),
      ],
    );
  }

  reviewScenario('Stop bei erfüllten Bedingungen fragt genau einmal an', (h) {
    h.act(() => h.vm.startOrStopTimer());
    expect(h.state.workEntry.workEnd, isNotNull);
    verify(requester.requestReview()).called(1);
    expect(prompts.prompted, isTrue);
    expect(promptedWhenRequested, isTrue,
        reason: 'Flag muss vor dem Aufruf gesetzt sein');
  });

  reviewScenario('bereits angefragt -> keine zweite Anfrage', (h) {
    h.act(() => h.vm.startOrStopTimer());
    verifyNever(requester.requestReview());
    expect(prompts.markPromptedCalls, 0);
  }, prompted: true);

  reviewScenario('Erstnutzung zu kurz her -> keine Anfrage', (h) {
    h.act(() => h.vm.startOrStopTimer());
    verifyNever(requester.requestReview());
    expect(prompts.prompted, isFalse);
  }, firstUse: DateTime(2026, 10, 1));

  reviewScenario('API nicht verfügbar -> nichts, Flag bleibt frei', (h) {
    h.act(() => h.vm.startOrStopTimer());
    verifyNever(requester.requestReview());
    expect(prompts.prompted, isFalse);
    expect(h.work.getMonthCalls, 0,
        reason: 'ohne API keine Lesezugriffe auf die Einträge');
  }, available: false);

  reviewScenario('Start des Timers fragt nie an', (h) {
    // Heute ist leer: der Tap startet nur.
    h.act(() => h.vm.startOrStopTimer());
    expect(h.state.workEntry.workStart, isNotNull);
    expect(h.state.workEntry.workEnd, isNull);
    verifyNever(requester.requestReview());
    expect(prompts.prompted, isFalse);
  }, runningToday: false);

  reviewScenario('Fehler der Review-API bleibt folgenlos', (h) {
    when(requester.requestReview()).thenThrow(Exception('play services'));
    bool? ok;
    h.act(() async => ok = await h.vm.startOrStopTimer());
    expect(ok, isTrue);
    expect(h.state.workEntry.workEnd, isNotNull);
    expect(h.state.isSaving, isFalse);
  });

  reviewScenario('Speicherfehler beim Stop -> keine Anfrage', (h) {
    h.work.failSaves = true;
    bool? ok;
    h.act(() async => ok = await h.vm.startOrStopTimer());
    expect(ok, isFalse);
    verifyNever(requester.requestReview());
    expect(prompts.prompted, isFalse);
  });
}
