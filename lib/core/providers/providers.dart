import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/version_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/utils/logger.dart';
import '../../data/datasources/remote/firestore_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/repositories/hybrid_overtime_repository_impl.dart';
import '../../data/repositories/hybrid_work_repository_impl.dart';
import '../../data/repositories/local_overtime_repository_impl.dart';
import '../../data/repositories/local_work_repository_impl.dart';
import '../../data/repositories/overtime_repository_impl.dart';
import '../../data/repositories/settings_repository_impl.dart';
import '../../data/repositories/work_repository_impl.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/overtime_repository.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/repositories/work_repository.dart';
import '../../domain/usecases/delete_account.dart';
import '../../domain/usecases/get_auth_state_changes.dart';
import '../../domain/usecases/get_theme_mode.dart';
import '../../domain/usecases/get_today_work_entry.dart';
import '../../domain/usecases/get_work_entries_for_month.dart';
import '../../domain/usecases/overtime_usecases.dart';
import '../../domain/usecases/save_work_entry.dart';
import '../../domain/usecases/set_theme_mode.dart';
import '../../domain/usecases/sign_in_with_google.dart';
import '../../domain/usecases/sign_out.dart';
import '../../domain/usecases/start_or_stop_timer.dart';
import '../../domain/usecases/toggle_break.dart';

part 'providers.g.dart';

//==============================================================================
// DATA SOURCES & 3RD PARTY
//==============================================================================

@Riverpod(keepAlive: true)
FirebaseAuth firebaseAuth(Ref ref) => FirebaseAuth.instance;

@Riverpod(keepAlive: true)
FirebaseFirestore firestore(Ref ref) => FirebaseFirestore.instance;

@Riverpod(keepAlive: true)
GoogleSignIn googleSignIn(Ref ref) => GoogleSignIn.instance;

@Riverpod(keepAlive: true)
SharedPreferences sharedPreferences(Ref ref) {
  throw UnimplementedError('SharedPreferencesProvider muss in main.dart überschrieben werden!');
}

@riverpod
FirestoreDataSource firestoreDataSource(Ref ref) {
  return FirestoreDataSourceImpl(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
    ref.watch(googleSignInProvider),
  );
}

//==============================================================================
// SERVICES
//==============================================================================

@riverpod
VersionService versionService(Ref ref) {
  return VersionService(ref.watch(firestoreProvider));
}

@riverpod
NotificationService notificationService(Ref ref) {
  return NotificationService();
}

//==============================================================================
// REPOSITORIES
//==============================================================================

@riverpod
AuthRepository authRepository(Ref ref) {
  return AuthRepositoryImpl(ref.watch(firestoreDataSourceProvider));
}

@riverpod
SettingsRepository settingsRepository(Ref ref) {
  final userId = ref.watch(firebaseAuthProvider).currentUser?.uid;
  return SettingsRepositoryImpl(
    ref.watch(sharedPreferencesProvider),
    ref.watch(firestoreDataSourceProvider),
    userId ?? 'local',
  );
}

@riverpod
WorkRepository workRepository(Ref ref) {
  final authState = ref.watch(authStateProvider);
  final userId = authState.asData?.value?.id;
  final prefs = ref.watch(sharedPreferencesProvider);

  logger.i('[workRepositoryProvider] Auth State geändert - userId: $userId');

  final localRepository = LocalWorkRepositoryImpl(prefs);

  final firebaseRepository = userId != null
      ? WorkRepositoryImpl(
          dataSource: ref.watch(firestoreDataSourceProvider),
          userId: userId,
        )
      : localRepository;

  return HybridWorkRepositoryImpl(
    firebaseRepository: firebaseRepository,
    localRepository: localRepository,
    userId: userId,
  );
}

@riverpod
OvertimeRepository overtimeRepository(Ref ref) {
  final authState = ref.watch(authStateProvider);
  final userId = authState.asData?.value?.id;
  final prefs = ref.watch(sharedPreferencesProvider);

  logger.i('[overtimeRepositoryProvider] Auth State geändert - userId: $userId');

  final localRepository = LocalOvertimeRepositoryImpl(prefs);

  final firebaseRepository = userId != null
      ? OvertimeRepositoryImpl(prefs, userId)
      : localRepository;

  return HybridOvertimeRepositoryImpl(
    firebaseRepository: firebaseRepository,
    localRepository: localRepository,
    userId: userId,
  );
}

//==============================================================================
// USE CASES
//==============================================================================

// --- Auth ---
@riverpod
GetAuthStateChanges getAuthStateChangesUseCase(Ref ref) {
  return GetAuthStateChanges(ref.watch(authRepositoryProvider));
}

@riverpod
Stream<UserEntity?> authState(Ref ref) {
  final useCase = ref.watch(getAuthStateChangesUseCaseProvider);
  return useCase();
}

@riverpod
SignInWithGoogle signInWithGoogleUseCase(Ref ref) {
  return SignInWithGoogle(ref.watch(authRepositoryProvider));
}

@riverpod
SignOut signOutUseCase(Ref ref) {
  return SignOut(ref.watch(authRepositoryProvider));
}

@riverpod
DeleteAccount deleteAccountUseCase(Ref ref) {
  return DeleteAccount(ref.watch(authRepositoryProvider));
}

// --- Settings ---
@riverpod
GetThemeMode getThemeModeUseCase(Ref ref) {
  return GetThemeMode(ref.watch(settingsRepositoryProvider));
}

@riverpod
SetThemeMode setThemeModeUseCase(Ref ref) {
  return SetThemeMode(ref.watch(settingsRepositoryProvider));
}

// --- Work Entries ---
@riverpod
GetTodayWorkEntry getTodayWorkEntryUseCase(Ref ref) {
  return GetTodayWorkEntry(ref.watch(workRepositoryProvider));
}

@riverpod
SaveWorkEntry saveWorkEntryUseCase(Ref ref) {
  return SaveWorkEntry(ref.watch(workRepositoryProvider));
}

@riverpod
ToggleBreak toggleBreakUseCase(Ref ref) {
  return ToggleBreak(ref.watch(workRepositoryProvider));
}

@riverpod
GetWorkEntriesForMonth getWorkEntriesForMonthUseCase(Ref ref) {
  return GetWorkEntriesForMonth(ref.watch(workRepositoryProvider));
}

@riverpod
StartOrStopTimer startOrStopTimerUseCase(Ref ref) {
  return StartOrStopTimer(ref.watch(workRepositoryProvider));
}

// --- Overtime ---
@riverpod
GetOvertime getOvertimeUseCase(Ref ref) {
  return GetOvertime(ref.watch(overtimeRepositoryProvider));
}

@riverpod
UpdateOvertime updateOvertimeUseCase(Ref ref) {
  return UpdateOvertime(ref.watch(overtimeRepositoryProvider));
}

@riverpod
SetOvertime setOvertimeUseCase(Ref ref) {
  return SetOvertime(ref.watch(overtimeRepositoryProvider));
}
