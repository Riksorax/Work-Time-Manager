import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/core/providers/subscription_provider.dart';
import 'package:flutter_work_time/domain/entities/user_entity.dart';
import 'package:flutter_work_time/domain/entities/work_profile_entity.dart';
import 'package:flutter_work_time/domain/repositories/work_profile_repository.dart';
import 'package:flutter_work_time/presentation/widgets/work_profile_switcher.dart';

import 'work_profile_switcher_test.mocks.dart';

@GenerateMocks([WorkProfileRepository])
void main() {
  late MockWorkProfileRepository mockRepository;
  late SharedPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  setUp(() {
    mockRepository = MockWorkProfileRepository();
    when(mockRepository.getAdditionalProfiles()).thenAnswer((_) async => []);
  });

  Widget createSubject({required bool isPremium}) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authStateProvider.overrideWithValue(
          const AsyncValue.data(UserEntity(id: '1', email: 'test@test.com')),
        ),
        workProfileRepositoryProvider.overrideWithValue(mockRepository),
        isPremiumProvider.overrideWithValue(isPremium),
      ],
      child: MaterialApp(
        home: Scaffold(appBar: AppBar(actions: const [WorkProfileSwitcher()])),
      ),
    );
  }

  group('WorkProfileSwitcher', () {
    testWidgets('rendert nichts, wenn kein Nutzer eingeloggt ist', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authStateProvider.overrideWithValue(const AsyncValue.data(null)),
          workProfileRepositoryProvider.overrideWithValue(mockRepository),
        ],
        child: MaterialApp(
          home: Scaffold(appBar: AppBar(actions: const [WorkProfileSwitcher()])),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(PopupMenuButton<String>), findsNothing);
    });

    testWidgets('zeigt Standard-Profil und Premium-Hinweis ohne Premium', (tester) async {
      await tester.pumpWidget(createSubject(isPremium: false));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      expect(find.text('Standard'), findsOneWidget);
      expect(find.text('Neues Profil'), findsOneWidget);

      await tester.tap(find.text('Neues Profil'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Premium-Feature'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('legt mit Premium ein neues Profil an', (tester) async {
      when(mockRepository.addProfile('Zweitjob'))
          .thenAnswer((_) async => const WorkProfileEntity(id: 'p1', name: 'Zweitjob'));

      await tester.pumpWidget(createSubject(isPremium: true));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Neues Profil'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Zweitjob');
      await tester.tap(find.text('Anlegen'));
      await tester.pumpAndSettle();

      verify(mockRepository.addProfile('Zweitjob')).called(1);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.textContaining('angelegt'), findsOneWidget);
    });
  });
}
