import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/domain/entities/user_entity.dart';
import 'package:flutter_work_time/domain/entities/work_profile_entity.dart';
import 'package:flutter_work_time/domain/repositories/work_profile_repository.dart';
import 'package:flutter_work_time/presentation/view_models/work_profile_view_model.dart';

import 'work_profile_view_model_test.mocks.dart';

const _loggedInUser = AsyncValue<UserEntity?>.data(UserEntity(id: 'uid1', email: 'test@test.com'));

@GenerateMocks([WorkProfileRepository])
void main() {
  late MockWorkProfileRepository mockRepository;
  late SharedPreferences prefs;
  late ProviderContainer container;

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() async {
    prefs = await SharedPreferences.getInstance();
    mockRepository = MockWorkProfileRepository();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authStateProvider.overrideWithValue(_loggedInUser),
        workProfileRepositoryProvider.overrideWithValue(mockRepository),
      ],
    );
  });

  tearDown(() => container.dispose());

  group('WorkProfileViewModel.addProfile', () {
    test('legt das Profil an und setzt es als aktiv', () async {
      const newProfile = WorkProfileEntity(id: 'p1', name: 'Nebenjob');
      when(mockRepository.addProfile('Nebenjob')).thenAnswer((_) async => newProfile);

      final result = await container.read(workProfileViewModelProvider).addProfile('Nebenjob');

      expect(result, newProfile);
      expect(container.read(activeWorkProfileIdProvider), 'p1');
      verify(mockRepository.addProfile('Nebenjob')).called(1);
    });

    test('wirft WorkProfilesNotAvailableException ohne eingeloggten Nutzer', () async {
      container.dispose();
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authStateProvider.overrideWithValue(const AsyncValue.data(null)),
          workProfileRepositoryProvider.overrideWithValue(null),
        ],
      );

      expect(
        () => container.read(workProfileViewModelProvider).addProfile('Nebenjob'),
        throwsA(isA<WorkProfilesNotAvailableException>()),
      );
    });
  });

  group('WorkProfileViewModel.deleteProfile', () {
    test('löscht das Profil und setzt bei aktivem Profil auf Standard zurück', () async {
      when(mockRepository.deleteProfile('p1')).thenAnswer((_) async {});
      await container.read(activeWorkProfileIdProvider.notifier).setActiveProfile('p1');

      await container.read(workProfileViewModelProvider).deleteProfile('p1');

      verify(mockRepository.deleteProfile('p1')).called(1);
      expect(container.read(activeWorkProfileIdProvider), isNull);
    });

    test('lässt ein anderes aktives Profil unangetastet', () async {
      when(mockRepository.deleteProfile('p1')).thenAnswer((_) async {});
      await container.read(activeWorkProfileIdProvider.notifier).setActiveProfile('p2');

      await container.read(workProfileViewModelProvider).deleteProfile('p1');

      expect(container.read(activeWorkProfileIdProvider), 'p2');
    });
  });
}
