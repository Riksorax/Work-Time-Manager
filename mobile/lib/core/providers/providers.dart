import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/version_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/utils/logger.dart';
import '../../data/datasources/remote/api_client.dart';
import '../../data/datasources/remote/api_data_source.dart';
import '../../data/datasources/remote/firestore_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/repositories/hybrid_overtime_repository_impl.dart';
import '../../data/repositories/hybrid_work_repository_impl.dart';
import '../../data/repositories/local_overtime_repository_impl.dart';
import '../../data/repositories/local_work_repository_impl.dart';
import '../../data/repositories/firebase_overtime_repository_impl.dart';
import '../../data/repositories/settings_repository_impl.dart';
import '../../data/repositories/weekly_reflection_repository_impl.dart';
import '../../data/repositories/work_profile_repository_impl.dart';
import '../../data/repositories/work_repository_impl.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/entities/work_profile_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/overtime_repository.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/repositories/weekly_reflection_repository.dart';
import '../../domain/repositories/work_profile_repository.dart';
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
GoogleSignIn googleSignIn(Ref ref) {
  // GoogleSignIn.instance ist ein vorkonfiguriertes Singleton
  // Für Web wird die clientId aus der index.html meta-tag gelesen
  // Für Android/iOS wird die Konfiguration aus den nativen Config-Dateien gelesen
  return GoogleSignIn.instance;
}

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

@Riverpod(keepAlive: true)
http.Client httpClient(Ref ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
}

@riverpod
ApiClient apiClient(Ref ref) =>
    ApiClient(ref.watch(firebaseAuthProvider), ref.watch(httpClientProvider));

/// Datenzugriff (Work/Overtime/Settings) über die Backend-API; Auth/Profil
/// delegiert an die Firestore-DataSource. Ersetzt die Firestore-DataSource im
/// "remote"-Slot der Hybrid-Repositories.
@riverpod
ApiDataSource apiDataSource(Ref ref) =>
    ApiDataSource(ref.watch(firestoreDataSourceProvider), ref.watch(apiClientProvider));

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
  final profileId = ref.watch(activeWorkProfileIdProvider);
  final repo = SettingsRepositoryImpl(
    ref.watch(sharedPreferencesProvider),
    ref.watch(apiDataSourceProvider),
    userId ?? 'local',
    profileId,
  );
  // Beim Login Firestore-Einstellungen in SharedPrefs übernehmen
  if (userId != null) repo.syncFromFirestore();
  return repo;
}

@riverpod
WorkRepository workRepository(Ref ref) {
  final authState = ref.watch(authStateProvider);
  final userId = authState.asData?.value?.id;
  final profileId = ref.watch(activeWorkProfileIdProvider);
  final prefs = ref.watch(sharedPreferencesProvider);

  logger.i('[workRepositoryProvider] Auth State geändert - userId: $userId, Profil: $profileId');

  final localRepository = LocalWorkRepositoryImpl(prefs);

  final firebaseRepository = userId != null
      ? WorkRepositoryImpl(
          dataSource: ref.watch(apiDataSourceProvider),
          userId: userId,
          profileId: profileId,
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
  final profileId = ref.watch(activeWorkProfileIdProvider);
  final prefs = ref.watch(sharedPreferencesProvider);

  logger.i('[overtimeRepositoryProvider] Auth State geändert - userId: $userId, Profil: $profileId');

  final localRepository = LocalOvertimeRepositoryImpl(prefs);

  final firebaseRepository = userId != null
      ? FirebaseOvertimeRepositoryImpl(
          dataSource: ref.watch(apiDataSourceProvider),
          userId: userId,
          profileId: profileId,
        )
      : localRepository;

  return HybridOvertimeRepositoryImpl(
    firebaseRepository: firebaseRepository,
    localRepository: localRepository,
    userId: userId,
  );
}

/// `null`, wenn kein Nutzer eingeloggt ist - anders als [WorkRepository]/
/// [OvertimeRepository] ohne Local-Fallback, da Wochen-Reflexionen ein
/// Premium-Feature sind und die UI ohnehin ein Login voraussetzt (#137).
@riverpod
WeeklyReflectionRepository? weeklyReflectionRepository(Ref ref) {
  final authState = ref.watch(authStateProvider);
  final userId = authState.asData?.value?.id;
  if (userId == null) return null;

  return WeeklyReflectionRepositoryImpl(
    dataSource: ref.watch(apiDataSourceProvider),
    userId: userId,
  );
}

/// `null`, wenn kein Nutzer eingeloggt ist - wie [WeeklyReflectionRepository]
/// ein Premium-Feature, das ein Login voraussetzt (#138).
@riverpod
WorkProfileRepository? workProfileRepository(Ref ref) {
  final authState = ref.watch(authStateProvider);
  final userId = authState.asData?.value?.id;
  if (userId == null) return null;

  return WorkProfileRepositoryImpl(
    dataSource: ref.watch(apiDataSourceProvider),
    userId: userId,
  );
}

//==============================================================================
// ARBEITSZEIT-PROFILE (siehe #138)
//==============================================================================

/// Alle Profile des Nutzers inkl. des stets vorhandenen Standard-Profils,
/// für den Profil-Wechsler in der UI.
@riverpod
Future<List<WorkProfileEntity>> workProfiles(Ref ref) async {
  final repository = ref.watch(workProfileRepositoryProvider);
  final profiles = [WorkProfileEntity.defaultProfile()];
  if (repository == null) return profiles;

  final additional = await repository.getAdditionalProfiles();
  return [...profiles, ...additional];
}

/// Das aktuell aktive Arbeitszeit-Profil (`null` = Standard-Profil). Wird
/// pro Nutzer in SharedPreferences gemerkt, damit ein App-Neustart nicht
/// unbemerkt auf das Standard-Profil zurückfällt (Gefahr fehlgeleiteter
/// Einträge, falls der Nutzer denkt, er sei noch im Zweitprofil).
final activeWorkProfileIdProvider =
    NotifierProvider<ActiveWorkProfileIdNotifier, String?>(
        ActiveWorkProfileIdNotifier.new);

class ActiveWorkProfileIdNotifier extends Notifier<String?> {
  static const _prefsKeyPrefix = 'active_work_profile_';

  @override
  String? build() {
    final userId = ref.watch(authStateProvider).asData?.value?.id;
    if (userId == null) return null;

    final prefs = ref.watch(sharedPreferencesProvider);
    final stored = prefs.getString('$_prefsKeyPrefix$userId');
    return (stored == null || stored == WorkProfileEntity.defaultProfileId) ? null : stored;
  }

  Future<void> setActiveProfile(String? profileId) async {
    final userId = ref.read(authStateProvider).asData?.value?.id;
    state = profileId;
    if (userId == null) return;

    final prefs = ref.read(sharedPreferencesProvider);
    if (profileId == null) {
      await prefs.remove('$_prefsKeyPrefix$userId');
    } else {
      await prefs.setString('$_prefsKeyPrefix$userId', profileId);
    }
  }
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

@riverpod
GetLastOvertimeUpdate getLastOvertimeUpdateUseCase(Ref ref) {
  return GetLastOvertimeUpdate(ref.watch(overtimeRepositoryProvider));
}