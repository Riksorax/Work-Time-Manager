import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/usecases/should_request_review.dart';

import '../../support/dashboard_harness.dart' show entryOf;
import '../../support/fake_repositories.dart';
import '../../support/fake_review_prompt_repository.dart';

// Feste Daten, unabhängig von Wochentag und Zeitzone: "heute" ist der
// 2026-10-15; die Erstnutzung genau 7 Tage davor (2026-10-08) erfüllt die
// Schwelle.
void main() {
  final today = DateTime(2026, 10, 15, 17);
  final sevenDaysAgo = DateTime(2026, 10, 8);

  late FakeReviewPromptRepository prompts;
  late FakeWorkRepository work;
  late ShouldRequestReviewUseCase useCase;

  /// Legt [count] abgeschlossene Arbeitstage ab 2026-10-01 an.
  void seedCompleted(int count, {int month = 10}) {
    for (var d = 1; d <= count; d++) {
      final day = DateTime(2026, month, d);
      work.store['$month-$d'] = entryOf(day,
          start: DateTime(2026, month, d, 8),
          end: DateTime(2026, month, d, 16));
    }
  }

  setUp(() {
    prompts = FakeReviewPromptRepository(firstUse: sevenDaysAgo);
    work = FakeWorkRepository();
    useCase = ShouldRequestReviewUseCase(prompts, work, clock: () => today);
  });

  test('alle Bedingungen erfüllt -> true', () async {
    seedCompleted(5);
    expect(await useCase(isTimerRunning: false), isTrue);
  });

  test('Erstnutzung zu kurz her -> false', () async {
    seedCompleted(5);
    prompts.firstUse = DateTime(2026, 10, 9); // 6 Tage
    expect(await useCase(isTimerRunning: false), isFalse);
  });

  test('zu wenige abgeschlossene Arbeitstage -> false', () async {
    seedCompleted(4);
    expect(await useCase(isTimerRunning: false), isFalse);
  });

  test('bereits angefragt -> false', () async {
    seedCompleted(5);
    prompts.prompted = true;
    expect(await useCase(isTimerRunning: false), isFalse);
  });

  test('Timer läuft -> false', () async {
    seedCompleted(5);
    expect(await useCase(isTimerRunning: true), isFalse);
    expect(work.getMonthCalls, 0,
        reason: 'kein Lesezugriff bei laufendem Timer');
  });

  test('offene, Urlaubs- und Krank-Einträge zählen nicht', () async {
    seedCompleted(3);
    work.store['open'] =
        entryOf(DateTime(2026, 10, 10), start: DateTime(2026, 10, 10, 8));
    work.store['vac'] = entryOf(DateTime(2026, 10, 11),
            start: DateTime(2026, 10, 11, 8), end: DateTime(2026, 10, 11, 16))
        .copyWith(type: WorkEntryType.vacation);
    work.store['sick'] = entryOf(DateTime(2026, 10, 12),
            start: DateTime(2026, 10, 12, 8), end: DateTime(2026, 10, 12, 16))
        .copyWith(type: WorkEntryType.sick);
    expect(await useCase(isTimerRunning: false), isFalse);
  });

  test('Arbeitstage aus mehreren Monaten werden summiert', () async {
    seedCompleted(2, month: 10);
    seedCompleted(3, month: 9);
    expect(await useCase(isTimerRunning: false), isTrue);
  });

  test('Monatswechsel über den Jahreswechsel hinweg', () async {
    useCase = ShouldRequestReviewUseCase(prompts, work,
        clock: () => DateTime(2026, 1, 20));
    prompts.firstUse = DateTime(2026, 1, 1);
    seedCompleted(5, month: 12); // wird als 2026-12 abgelegt: nicht im Fenster
    expect(await useCase(isTimerRunning: false), isFalse);
    work.store.clear();
    for (var d = 1; d <= 5; d++) {
      work.store['25-12-$d'] = entryOf(DateTime(2025, 12, d),
          start: DateTime(2025, 12, d, 8), end: DateTime(2025, 12, d, 16));
    }
    expect(await useCase(isTimerRunning: false), isTrue);
  });

  test('Lesefehler -> false, kein Wurf', () async {
    seedCompleted(5);
    work.failReads = true;
    expect(await useCase(isTimerRunning: false), isFalse);
  });

  test('ohne Erstnutzungsdatum wird es gesetzt, aber nicht angefragt',
      () async {
    seedCompleted(5);
    prompts.firstUse = null;
    expect(await useCase(isTimerRunning: false), isFalse);
    expect(prompts.firstUse, DateTime(2026, 10, 15));
  });

  test('markRequested setzt das Flag dauerhaft', () async {
    seedCompleted(5);
    expect(await useCase(isTimerRunning: false), isTrue);
    await useCase.markRequested();
    expect(prompts.markPromptedCalls, 1);
    expect(await useCase(isTimerRunning: false), isFalse);
  });

  test('Sommerzeitwechsel verfälscht die Tagesdifferenz nicht', () async {
    // 2026-10-25 ist der Wechsel auf Winterzeit (Europa); 7 Kalendertage.
    useCase = ShouldRequestReviewUseCase(prompts, work,
        clock: () => DateTime(2026, 10, 29, 12));
    prompts.firstUse = DateTime(2026, 10, 22);
    seedCompleted(5);
    expect(await useCase(isTimerRunning: false), isTrue);
  });
}
