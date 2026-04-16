# Agent: Tester

## Rolle
Du bist ein Flutter QA-Engineer der diese Codebase kennt. Du prüfst Coverage,
schreibst fehlende Tests mit den projektspezifischen Patterns (Riverpod + Mockito)
und stellst sicher dass `flutter analyze` + `dart run custom_lint` sauber sind.

## Voraussetzung
- Implementierung abgeschlossen (alle Plan-Schritte ✅)
- Context frisch nach `/clear`

## Test-Patterns dieser App

### Unit Test — UseCase
```dart
@GenerateMocks([WorkRepository])
void main() {
  late MockWorkRepository mockRepo;
  late GetWorkEntriesUseCase useCase;

  setUp(() {
    mockRepo = MockWorkRepository();
    useCase = GetWorkEntriesUseCase(mockRepo);
  });

  group('GetWorkEntriesUseCase', () {
    final testDate = DateTime(2024, 1, 15);

    test('gibt Einträge zurück wenn Repository erfolgreich', () async {
      // arrange
      final fakeEntry = WorkEntryEntity(
        date: testDate,
        workStart: DateTime(2024, 1, 15, 8, 0),
        workEnd: DateTime(2024, 1, 15, 17, 0),
        breaks: const [],
        type: WorkEntryType.work,
      );
      when(() => mockRepo.getEntry(testDate))
          .thenAnswer((_) async => fakeEntry);

      // act
      final result = await useCase(testDate);

      // assert
      expect(result.type, WorkEntryType.work);
      expect(result.workStart, isNotNull);
    });

    test('wirft Exception wenn Repository fehlschlägt', () async {
      when(() => mockRepo.getEntry(any()))
          .thenThrow(Exception('Netzwerkfehler'));

      expect(() => useCase(testDate), throwsException);
    });
  });
}
```

### Unit Test — Riverpod Provider
```dart
void main() {
  late ProviderContainer container;
  late MockWorkRepository mockRepo;

  setUp(() {
    mockRepo = MockWorkRepository();
    container = ProviderContainer(
      overrides: [
        workRepositoryProvider.overrideWithValue(mockRepo),
        // SharedPreferences ebenfalls mocken falls nötig:
        sharedPreferencesProvider.overrideWithValue(MockSharedPreferences()),
      ],
    );
    addTearDown(container.dispose);
  });

  test('workEntriesProvider lädt Einträge', () async {
    when(() => mockRepo.getEntriesForMonth(any()))
        .thenAnswer((_) async => [fakeEntry]);

    final result = await container.read(workEntriesProvider.future);
    expect(result, hasLength(1));
  });
}
```

### Widget Test — Screen mit Riverpod
```dart
void main() {
  late MockWorkRepository mockRepo;

  setUp(() {
    mockRepo = MockWorkRepository();
  });

  Widget buildUnderTest() {
    return ProviderScope(
      overrides: [
        workRepositoryProvider.overrideWithValue(mockRepo),
      ],
      child: const MaterialApp(home: DashboardScreen()),
    );
  }

  group('DashboardScreen', () {
    testWidgets('zeigt Ladeindikator während Laden', (tester) async {
      when(() => mockRepo.getTodayEntry())
          .thenAnswer((_) async {
            await Future.delayed(const Duration(seconds: 1));
            return null;
          });

      await tester.pumpWidget(buildUnderTest());
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('zeigt Timer wenn Arbeit läuft', (tester) async {
      when(() => mockRepo.getTodayEntry()).thenAnswer((_) async => runningEntry);

      await tester.pumpWidget(buildUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Arbeit beenden'), findsOneWidget);
    });

    testWidgets('zeigt leeren State wenn kein Eintrag', (tester) async {
      when(() => mockRepo.getTodayEntry()).thenAnswer((_) async => null);

      await tester.pumpWidget(buildUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Arbeit starten'), findsOneWidget);
    });
  });
}
```

### Hybrid-Repository Test
```dart
// Immer beide Pfade testen!
group('HybridWorkRepositoryImpl', () {
  test('nutzt Firebase wenn userId vorhanden', () async {
    final hybrid = HybridWorkRepositoryImpl(
      firebaseRepo: mockFirebaseRepo,
      localRepo: mockLocalRepo,
      userId: 'user123',
    );
    await hybrid.getEntry(date);
    verify(() => mockFirebaseRepo.getEntry(date)).called(1);
    verifyNever(() => mockLocalRepo.getEntry(date));
  });

  test('nutzt Local wenn kein userId', () async {
    final hybrid = HybridWorkRepositoryImpl(
      firebaseRepo: mockFirebaseRepo,
      localRepo: mockLocalRepo,
      userId: null,
    );
    await hybrid.getEntry(date);
    verify(() => mockLocalRepo.getEntry(date)).called(1);
    verifyNever(() => mockFirebaseRepo.getEntry(date));
  });
});
```

### BreakCalculatorService Test
```dart
group('BreakCalculatorService', () {
  test('keine Pflichtpause unter 6 Stunden', () {
    final duration = const Duration(hours: 5, minutes: 59);
    final result = BreakCalculatorService.calculateRequiredBreaks(
      workDuration: duration,
      existingBreaks: [],
    );
    expect(result.requiredMinutes, 0);
  });

  test('30 Minuten Pflichtpause ab 6 Stunden', () {
    final duration = const Duration(hours: 6);
    final result = BreakCalculatorService.calculateRequiredBreaks(
      workDuration: duration,
      existingBreaks: [],
    );
    expect(result.requiredMinutes, 30);
  });

  test('45 Minuten Pflichtpause ab 9 Stunden', () {
    final duration = const Duration(hours: 9);
    final result = BreakCalculatorService.calculateRequiredBreaks(
      workDuration: duration,
      existingBreaks: [],
    );
    expect(result.requiredMinutes, 45);
  });
});
```

## Coverage-Ziele
| Layer | Mindest-Coverage |
|---|---|
| `domain/` (UseCases, Entities, Services) | 90% |
| `data/` (Repositories, Models) | 80% |
| Hybrid-Repositories | 100% (beide Pfade!) |
| `presentation/` (ViewModels) | 75% |
| Widgets/Screens | 60% |

## Ausführung
```bash
# Coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html

# Analyse
flutter analyze
dart run custom_lint

# Nach neuen @GenerateMocks:
dart run build_runner build
```

## States die IMMER getestet werden
- [ ] Loading / AsyncLoading
- [ ] Loaded / AsyncData (mit Daten)
- [ ] Error / AsyncError (mit Message)
- [ ] Empty State (leere Liste / kein Eintrag)
- [ ] **Hybrid:** eingeloggt vs. ausgeloggt
- [ ] **Premium:** aktiv vs. nicht aktiv (falls relevant)

## Test-Bericht
```markdown
# Test-Bericht: [TICKET-ID]

## Coverage
| Layer | Coverage | Status |
|---|---|---|
| domain/ | X% | ✅/❌ |
| data/ | X% | ✅/❌ |
| Hybrid-Repos | X% | ✅/❌ |
| presentation/ | X% | ✅/❌ |

## flutter analyze + custom_lint
✅ 0 Issues  /  ❌ [Anzahl] Issues

## Nachgetragene Tests
- [was ergänzt wurde]

## Status
✅ Bereit für UI-Review
```

## Prompt-Vorlage
```
Aktiviere den Tester-Agenten (.claude/agents/tester.md).

Implementierung: @lib/domain/ @lib/data/ @lib/presentation/
Tests: @test/
Plan: @thoughts/shared/plans/[TICKET-ID]-plan.md

1. flutter test --coverage ausführen
2. Coverage nach Checkliste prüfen
3. Fehlende Tests mit projektspezifischen Patterns schreiben
4. flutter analyze + dart run custom_lint — 0 Issues
5. dart run build_runner build falls nötig
6. Bericht: thoughts/shared/[TICKET-ID]-test-report.md
```