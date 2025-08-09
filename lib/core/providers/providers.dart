import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/datasources/local/storage_datasource.dart';
import '../../data/datasources/remote/firestore_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/repositories/settings_repository_impl.dart' as impl;
import '../../data/repositories/work_repository_impl.dart';
import '../../domain/entities/work_entry_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/overtime_repository.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/repositories/work_repository.dart';
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
import '../../presentation/view_models/auth_view_model.dart';

//==============================================================================
// SCHICHT 1: DATA SOURCES PROVIDERS
//==============================================================================

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);
final googleSignInProvider = Provider<GoogleSignIn>((ref) => GoogleSignIn.instance);

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferencesProvider wurde nicht überschrieben');
});

final firestoreDataSourceProvider = Provider<FirestoreDataSource>((ref) {
  return FirestoreDataSourceImpl(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
    ref.watch(googleSignInProvider),
  );
});

final storageDataSourceProvider = Provider<StorageDataSource>((ref) {
  return StorageDataSourceImpl(ref.watch(sharedPreferencesProvider));
});

//==============================================================================
// SCHICHT 2: REPOSITORY PROVIDERS
//==============================================================================

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.watch(firestoreDataSourceProvider));
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return impl.SettingsRepositoryImpl(ref.watch(sharedPreferencesProvider));
});

/// Provider für das OvertimeRepository.
final overtimeRepositoryProvider = Provider<OvertimeRepository>((ref) {
  return OvertimeRepositoryImpl(ref.watch(storageDataSourceProvider));
});

class NoOpWorkRepository implements WorkRepository {
  @override
  Future<WorkEntryEntity> getWorkEntry(DateTime date) async {
    return WorkEntryEntity(
      id: date.toIso8601String(),
      date: date,
    );
  }

  @override
  Future<void> saveWorkEntry(WorkEntryEntity entry) async {}

  @override
  Future<List<WorkEntryEntity>> getWorkEntriesForMonth(int year, int month) async {
    return [];
  }
}

final workRepositoryProvider = Provider<WorkRepository>((ref) {
  final authState = ref.watch(authStateProvider);
  final userId = authState.valueOrNull?.id;

  if (userId == null) {
    return NoOpWorkRepository();
  }

  return WorkRepositoryImpl(
    dataSource: ref.watch(firestoreDataSourceProvider),
    userId: userId,
  );
});

//==============================================================================
// SCHICHT 3: USE CASE PROVIDERS
//==============================================================================

// --- Auth Use Cases ---
final getAuthStateChangesUseCaseProvider = Provider(
  (ref) => GetAuthStateChanges(ref.watch(authRepositoryProvider)),
);
final signInWithGoogleUseCaseProvider = Provider(
  (ref) => SignInWithGoogle(ref.watch(authRepositoryProvider)),
);
final signOutUseCaseProvider = Provider(
  (ref) => SignOut(ref.watch(authRepositoryProvider)),
);

// --- Settings Use Cases ---
final getThemeModeUseCaseProvider = Provider(
  (ref) => GetThemeMode(ref.watch(settingsRepositoryProvider)),
);
final setThemeModeUseCaseProvider = Provider(
  (ref) => SetThemeMode(ref.watch(settingsRepositoryProvider)),
);

// --- Overtime Use Cases ---
final getOvertimeUseCaseProvider = Provider(
  (ref) => GetOvertime(ref.watch(overtimeRepositoryProvider)),
);
final updateOvertimeUseCaseProvider = Provider(
  (ref) => UpdateOvertime(ref.watch(overtimeRepositoryProvider)),
);

// --- Work Entry Use Cases ---
final getTodayWorkEntryUseCaseProvider = Provider(
  (ref) => GetTodayWorkEntry(ref.watch(workRepositoryProvider)),
);
final saveWorkEntryUseCaseProvider = Provider(
  (ref) => SaveWorkEntry(ref.watch(workRepositoryProvider)),
);
final getWorkEntriesForMonthUseCaseProvider = Provider(
  (ref) => GetWorkEntriesForMonth(ref.watch(workRepositoryProvider)),
);
final startOrStopTimerUseCaseProvider = Provider(
  (ref) => StartOrStopTimer(ref.watch(workRepositoryProvider)),
);
