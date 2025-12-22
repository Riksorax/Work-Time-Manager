// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(firebaseAuth)
const firebaseAuthProvider = FirebaseAuthProvider._();

final class FirebaseAuthProvider
    extends $FunctionalProvider<FirebaseAuth, FirebaseAuth, FirebaseAuth>
    with $Provider<FirebaseAuth> {
  const FirebaseAuthProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'firebaseAuthProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$firebaseAuthHash();

  @$internal
  @override
  $ProviderElement<FirebaseAuth> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FirebaseAuth create(Ref ref) {
    return firebaseAuth(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FirebaseAuth value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FirebaseAuth>(value),
    );
  }
}

String _$firebaseAuthHash() => r'8c3e9d11b27110ca96130356b5ef4d5d34a5ffc2';

@ProviderFor(firestore)
const firestoreProvider = FirestoreProvider._();

final class FirestoreProvider extends $FunctionalProvider<FirebaseFirestore,
    FirebaseFirestore, FirebaseFirestore> with $Provider<FirebaseFirestore> {
  const FirestoreProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'firestoreProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$firestoreHash();

  @$internal
  @override
  $ProviderElement<FirebaseFirestore> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FirebaseFirestore create(Ref ref) {
    return firestore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FirebaseFirestore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FirebaseFirestore>(value),
    );
  }
}

String _$firestoreHash() => r'864285def6284159b44f9598dcde96347e0c1dce';

@ProviderFor(googleSignIn)
const googleSignInProvider = GoogleSignInProvider._();

final class GoogleSignInProvider
    extends $FunctionalProvider<GoogleSignIn, GoogleSignIn, GoogleSignIn>
    with $Provider<GoogleSignIn> {
  const GoogleSignInProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'googleSignInProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$googleSignInHash();

  @$internal
  @override
  $ProviderElement<GoogleSignIn> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GoogleSignIn create(Ref ref) {
    return googleSignIn(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GoogleSignIn value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GoogleSignIn>(value),
    );
  }
}

String _$googleSignInHash() => r'be6e657edfb1790d127cff1d3820a50c34e65011';

@ProviderFor(sharedPreferences)
const sharedPreferencesProvider = SharedPreferencesProvider._();

final class SharedPreferencesProvider extends $FunctionalProvider<
    SharedPreferences,
    SharedPreferences,
    SharedPreferences> with $Provider<SharedPreferences> {
  const SharedPreferencesProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'sharedPreferencesProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$sharedPreferencesHash();

  @$internal
  @override
  $ProviderElement<SharedPreferences> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SharedPreferences create(Ref ref) {
    return sharedPreferences(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SharedPreferences value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SharedPreferences>(value),
    );
  }
}

String _$sharedPreferencesHash() => r'f8324c100569e6c9e54b9728411ba0785251c75f';

@ProviderFor(firestoreDataSource)
const firestoreDataSourceProvider = FirestoreDataSourceProvider._();

final class FirestoreDataSourceProvider extends $FunctionalProvider<
    FirestoreDataSource,
    FirestoreDataSource,
    FirestoreDataSource> with $Provider<FirestoreDataSource> {
  const FirestoreDataSourceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'firestoreDataSourceProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$firestoreDataSourceHash();

  @$internal
  @override
  $ProviderElement<FirestoreDataSource> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FirestoreDataSource create(Ref ref) {
    return firestoreDataSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FirestoreDataSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FirestoreDataSource>(value),
    );
  }
}

String _$firestoreDataSourceHash() =>
    r'8c794a60f391c62f58c6da49f2a8d5576a9b093f';

@ProviderFor(versionService)
const versionServiceProvider = VersionServiceProvider._();

final class VersionServiceProvider
    extends $FunctionalProvider<VersionService, VersionService, VersionService>
    with $Provider<VersionService> {
  const VersionServiceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'versionServiceProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$versionServiceHash();

  @$internal
  @override
  $ProviderElement<VersionService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  VersionService create(Ref ref) {
    return versionService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VersionService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VersionService>(value),
    );
  }
}

String _$versionServiceHash() => r'756a954b4b8b851fa66cfb727ae6be25e8d3ebff';

@ProviderFor(notificationService)
const notificationServiceProvider = NotificationServiceProvider._();

final class NotificationServiceProvider extends $FunctionalProvider<
    NotificationService,
    NotificationService,
    NotificationService> with $Provider<NotificationService> {
  const NotificationServiceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'notificationServiceProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$notificationServiceHash();

  @$internal
  @override
  $ProviderElement<NotificationService> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  NotificationService create(Ref ref) {
    return notificationService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NotificationService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NotificationService>(value),
    );
  }
}

String _$notificationServiceHash() =>
    r'cda5ea9d196dce85bee56839a4a0f035021752e3';

@ProviderFor(authRepository)
const authRepositoryProvider = AuthRepositoryProvider._();

final class AuthRepositoryProvider
    extends $FunctionalProvider<AuthRepository, AuthRepository, AuthRepository>
    with $Provider<AuthRepository> {
  const AuthRepositoryProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'authRepositoryProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$authRepositoryHash();

  @$internal
  @override
  $ProviderElement<AuthRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AuthRepository create(Ref ref) {
    return authRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthRepository>(value),
    );
  }
}

String _$authRepositoryHash() => r'c70898d31a286230167c40d06d08c12c7429da5d';

@ProviderFor(settingsRepository)
const settingsRepositoryProvider = SettingsRepositoryProvider._();

final class SettingsRepositoryProvider extends $FunctionalProvider<
    SettingsRepository,
    SettingsRepository,
    SettingsRepository> with $Provider<SettingsRepository> {
  const SettingsRepositoryProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'settingsRepositoryProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$settingsRepositoryHash();

  @$internal
  @override
  $ProviderElement<SettingsRepository> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SettingsRepository create(Ref ref) {
    return settingsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SettingsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SettingsRepository>(value),
    );
  }
}

String _$settingsRepositoryHash() =>
    r'18140d9186a20eb7e032cfcd7abe504f81c67a61';

@ProviderFor(workRepository)
const workRepositoryProvider = WorkRepositoryProvider._();

final class WorkRepositoryProvider
    extends $FunctionalProvider<WorkRepository, WorkRepository, WorkRepository>
    with $Provider<WorkRepository> {
  const WorkRepositoryProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'workRepositoryProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$workRepositoryHash();

  @$internal
  @override
  $ProviderElement<WorkRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  WorkRepository create(Ref ref) {
    return workRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorkRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorkRepository>(value),
    );
  }
}

String _$workRepositoryHash() => r'80410f292c560043c1f9655de73a3fd85abacd5f';

@ProviderFor(overtimeRepository)
const overtimeRepositoryProvider = OvertimeRepositoryProvider._();

final class OvertimeRepositoryProvider extends $FunctionalProvider<
    OvertimeRepository,
    OvertimeRepository,
    OvertimeRepository> with $Provider<OvertimeRepository> {
  const OvertimeRepositoryProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'overtimeRepositoryProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$overtimeRepositoryHash();

  @$internal
  @override
  $ProviderElement<OvertimeRepository> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  OvertimeRepository create(Ref ref) {
    return overtimeRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OvertimeRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OvertimeRepository>(value),
    );
  }
}

String _$overtimeRepositoryHash() =>
    r'bf02e8d5e2e75c47adbb506503ac4668e9dc5e38';

@ProviderFor(getAuthStateChangesUseCase)
const getAuthStateChangesUseCaseProvider =
    GetAuthStateChangesUseCaseProvider._();

final class GetAuthStateChangesUseCaseProvider extends $FunctionalProvider<
    GetAuthStateChanges,
    GetAuthStateChanges,
    GetAuthStateChanges> with $Provider<GetAuthStateChanges> {
  const GetAuthStateChangesUseCaseProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'getAuthStateChangesUseCaseProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$getAuthStateChangesUseCaseHash();

  @$internal
  @override
  $ProviderElement<GetAuthStateChanges> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GetAuthStateChanges create(Ref ref) {
    return getAuthStateChangesUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GetAuthStateChanges value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GetAuthStateChanges>(value),
    );
  }
}

String _$getAuthStateChangesUseCaseHash() =>
    r'bf7bbf319ae6847141c8809c2aff872414959612';

@ProviderFor(authState)
const authStateProvider = AuthStateProvider._();

final class AuthStateProvider extends $FunctionalProvider<
        AsyncValue<UserEntity?>, UserEntity?, Stream<UserEntity?>>
    with $FutureModifier<UserEntity?>, $StreamProvider<UserEntity?> {
  const AuthStateProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'authStateProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$authStateHash();

  @$internal
  @override
  $StreamProviderElement<UserEntity?> $createElement(
          $ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<UserEntity?> create(Ref ref) {
    return authState(ref);
  }
}

String _$authStateHash() => r'cc8c06b81674631de67c15f23fa1ae48ad242ca7';

@ProviderFor(signInWithGoogleUseCase)
const signInWithGoogleUseCaseProvider = SignInWithGoogleUseCaseProvider._();

final class SignInWithGoogleUseCaseProvider extends $FunctionalProvider<
    SignInWithGoogle,
    SignInWithGoogle,
    SignInWithGoogle> with $Provider<SignInWithGoogle> {
  const SignInWithGoogleUseCaseProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'signInWithGoogleUseCaseProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$signInWithGoogleUseCaseHash();

  @$internal
  @override
  $ProviderElement<SignInWithGoogle> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SignInWithGoogle create(Ref ref) {
    return signInWithGoogleUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SignInWithGoogle value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SignInWithGoogle>(value),
    );
  }
}

String _$signInWithGoogleUseCaseHash() =>
    r'6001dd6f5babe8a3a80b9160392511ac27a1eed7';

@ProviderFor(signOutUseCase)
const signOutUseCaseProvider = SignOutUseCaseProvider._();

final class SignOutUseCaseProvider
    extends $FunctionalProvider<SignOut, SignOut, SignOut>
    with $Provider<SignOut> {
  const SignOutUseCaseProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'signOutUseCaseProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$signOutUseCaseHash();

  @$internal
  @override
  $ProviderElement<SignOut> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SignOut create(Ref ref) {
    return signOutUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SignOut value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SignOut>(value),
    );
  }
}

String _$signOutUseCaseHash() => r'b625f35bebc61e8c1a7e7d0f6b3ba99912b8d1fc';

@ProviderFor(deleteAccountUseCase)
const deleteAccountUseCaseProvider = DeleteAccountUseCaseProvider._();

final class DeleteAccountUseCaseProvider
    extends $FunctionalProvider<DeleteAccount, DeleteAccount, DeleteAccount>
    with $Provider<DeleteAccount> {
  const DeleteAccountUseCaseProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'deleteAccountUseCaseProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$deleteAccountUseCaseHash();

  @$internal
  @override
  $ProviderElement<DeleteAccount> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DeleteAccount create(Ref ref) {
    return deleteAccountUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DeleteAccount value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DeleteAccount>(value),
    );
  }
}

String _$deleteAccountUseCaseHash() =>
    r'5747087227f34cde6bc13863f0b2071d4c66c123';

@ProviderFor(getThemeModeUseCase)
const getThemeModeUseCaseProvider = GetThemeModeUseCaseProvider._();

final class GetThemeModeUseCaseProvider
    extends $FunctionalProvider<GetThemeMode, GetThemeMode, GetThemeMode>
    with $Provider<GetThemeMode> {
  const GetThemeModeUseCaseProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'getThemeModeUseCaseProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$getThemeModeUseCaseHash();

  @$internal
  @override
  $ProviderElement<GetThemeMode> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GetThemeMode create(Ref ref) {
    return getThemeModeUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GetThemeMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GetThemeMode>(value),
    );
  }
}

String _$getThemeModeUseCaseHash() =>
    r'875809a1996729cf44843e83bb83a33369d5f6ba';

@ProviderFor(setThemeModeUseCase)
const setThemeModeUseCaseProvider = SetThemeModeUseCaseProvider._();

final class SetThemeModeUseCaseProvider
    extends $FunctionalProvider<SetThemeMode, SetThemeMode, SetThemeMode>
    with $Provider<SetThemeMode> {
  const SetThemeModeUseCaseProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'setThemeModeUseCaseProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$setThemeModeUseCaseHash();

  @$internal
  @override
  $ProviderElement<SetThemeMode> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SetThemeMode create(Ref ref) {
    return setThemeModeUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SetThemeMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SetThemeMode>(value),
    );
  }
}

String _$setThemeModeUseCaseHash() =>
    r'1e09916a86847fb2d2e7c4200824938b0449761e';

@ProviderFor(getTodayWorkEntryUseCase)
const getTodayWorkEntryUseCaseProvider = GetTodayWorkEntryUseCaseProvider._();

final class GetTodayWorkEntryUseCaseProvider extends $FunctionalProvider<
    GetTodayWorkEntry,
    GetTodayWorkEntry,
    GetTodayWorkEntry> with $Provider<GetTodayWorkEntry> {
  const GetTodayWorkEntryUseCaseProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'getTodayWorkEntryUseCaseProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$getTodayWorkEntryUseCaseHash();

  @$internal
  @override
  $ProviderElement<GetTodayWorkEntry> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GetTodayWorkEntry create(Ref ref) {
    return getTodayWorkEntryUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GetTodayWorkEntry value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GetTodayWorkEntry>(value),
    );
  }
}

String _$getTodayWorkEntryUseCaseHash() =>
    r'ceea9e9e54d584a5e90610ae3e7bc41ab19bbb7a';

@ProviderFor(saveWorkEntryUseCase)
const saveWorkEntryUseCaseProvider = SaveWorkEntryUseCaseProvider._();

final class SaveWorkEntryUseCaseProvider
    extends $FunctionalProvider<SaveWorkEntry, SaveWorkEntry, SaveWorkEntry>
    with $Provider<SaveWorkEntry> {
  const SaveWorkEntryUseCaseProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'saveWorkEntryUseCaseProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$saveWorkEntryUseCaseHash();

  @$internal
  @override
  $ProviderElement<SaveWorkEntry> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SaveWorkEntry create(Ref ref) {
    return saveWorkEntryUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SaveWorkEntry value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SaveWorkEntry>(value),
    );
  }
}

String _$saveWorkEntryUseCaseHash() =>
    r'822f82b9ad54a254e8a10d23590818a56217d2ce';

@ProviderFor(toggleBreakUseCase)
const toggleBreakUseCaseProvider = ToggleBreakUseCaseProvider._();

final class ToggleBreakUseCaseProvider
    extends $FunctionalProvider<ToggleBreak, ToggleBreak, ToggleBreak>
    with $Provider<ToggleBreak> {
  const ToggleBreakUseCaseProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'toggleBreakUseCaseProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$toggleBreakUseCaseHash();

  @$internal
  @override
  $ProviderElement<ToggleBreak> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ToggleBreak create(Ref ref) {
    return toggleBreakUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ToggleBreak value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ToggleBreak>(value),
    );
  }
}

String _$toggleBreakUseCaseHash() =>
    r'761d763d291fdc270cffac41912025c2309287bd';

@ProviderFor(getWorkEntriesForMonthUseCase)
const getWorkEntriesForMonthUseCaseProvider =
    GetWorkEntriesForMonthUseCaseProvider._();

final class GetWorkEntriesForMonthUseCaseProvider extends $FunctionalProvider<
    GetWorkEntriesForMonth,
    GetWorkEntriesForMonth,
    GetWorkEntriesForMonth> with $Provider<GetWorkEntriesForMonth> {
  const GetWorkEntriesForMonthUseCaseProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'getWorkEntriesForMonthUseCaseProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$getWorkEntriesForMonthUseCaseHash();

  @$internal
  @override
  $ProviderElement<GetWorkEntriesForMonth> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GetWorkEntriesForMonth create(Ref ref) {
    return getWorkEntriesForMonthUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GetWorkEntriesForMonth value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GetWorkEntriesForMonth>(value),
    );
  }
}

String _$getWorkEntriesForMonthUseCaseHash() =>
    r'8df8919bf44e55cc74b00862746042761d2b284c';

@ProviderFor(startOrStopTimerUseCase)
const startOrStopTimerUseCaseProvider = StartOrStopTimerUseCaseProvider._();

final class StartOrStopTimerUseCaseProvider extends $FunctionalProvider<
    StartOrStopTimer,
    StartOrStopTimer,
    StartOrStopTimer> with $Provider<StartOrStopTimer> {
  const StartOrStopTimerUseCaseProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'startOrStopTimerUseCaseProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$startOrStopTimerUseCaseHash();

  @$internal
  @override
  $ProviderElement<StartOrStopTimer> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  StartOrStopTimer create(Ref ref) {
    return startOrStopTimerUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StartOrStopTimer value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StartOrStopTimer>(value),
    );
  }
}

String _$startOrStopTimerUseCaseHash() =>
    r'6c5204912d94456a3bf558b3ac1b17c9b29a2b2a';

@ProviderFor(getOvertimeUseCase)
const getOvertimeUseCaseProvider = GetOvertimeUseCaseProvider._();

final class GetOvertimeUseCaseProvider
    extends $FunctionalProvider<GetOvertime, GetOvertime, GetOvertime>
    with $Provider<GetOvertime> {
  const GetOvertimeUseCaseProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'getOvertimeUseCaseProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$getOvertimeUseCaseHash();

  @$internal
  @override
  $ProviderElement<GetOvertime> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GetOvertime create(Ref ref) {
    return getOvertimeUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GetOvertime value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GetOvertime>(value),
    );
  }
}

String _$getOvertimeUseCaseHash() =>
    r'afc8e224ff7b14ae34d4ff7f3eb4524b44ba5b24';

@ProviderFor(updateOvertimeUseCase)
const updateOvertimeUseCaseProvider = UpdateOvertimeUseCaseProvider._();

final class UpdateOvertimeUseCaseProvider
    extends $FunctionalProvider<UpdateOvertime, UpdateOvertime, UpdateOvertime>
    with $Provider<UpdateOvertime> {
  const UpdateOvertimeUseCaseProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'updateOvertimeUseCaseProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$updateOvertimeUseCaseHash();

  @$internal
  @override
  $ProviderElement<UpdateOvertime> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  UpdateOvertime create(Ref ref) {
    return updateOvertimeUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UpdateOvertime value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UpdateOvertime>(value),
    );
  }
}

String _$updateOvertimeUseCaseHash() =>
    r'9906c542f68f20872623d95f2b0d19425c4f25bd';

@ProviderFor(setOvertimeUseCase)
const setOvertimeUseCaseProvider = SetOvertimeUseCaseProvider._();

final class SetOvertimeUseCaseProvider
    extends $FunctionalProvider<SetOvertime, SetOvertime, SetOvertime>
    with $Provider<SetOvertime> {
  const SetOvertimeUseCaseProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'setOvertimeUseCaseProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$setOvertimeUseCaseHash();

  @$internal
  @override
  $ProviderElement<SetOvertime> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SetOvertime create(Ref ref) {
    return setOvertimeUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SetOvertime value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SetOvertime>(value),
    );
  }
}

String _$setOvertimeUseCaseHash() =>
    r'936ce8199bf7b8f484def7a3fbd09c3877cc1da4';
