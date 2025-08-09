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
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/repositories/work_repository.dart';
import '../../domain/usecases/get_auth_state_changes.dart';
import '../../domain/usecases/get_theme_mode.dart';
import '../../domain/usecases/get_today_work_entry.dart';
import '../../domain/usecases/get_work_entries_for_month.dart';
import '../../domain/usecases/save_work_entry.dart';
import '../../domain/usecases/set_theme_mode.dart';
import '../../domain/usecases/sign_in_with_google.dart';
import '../../domain/usecases/sign_out.dart';
import '../../domain/usecases/start_or_stop_timer.dart';
import '../../domain/usecases/toggle_break.dart';
import '../../presentation/view_models/auth_view_model.dart';

//==============================================================================
// SCHICHT 1: DATA SOURCES PROVIDERS
// Diese Provider stellen die unterste Schicht bereit: direkten Zugriff auf externe Dienste.
//==============================================================================

/// Provider für die Firebase Auth Instanz.
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

/// Provider für die Cloud Firestore Instanz.
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

/// Provider für die Google Sign-In Instanz.
final googleSignInProvider = Provider<GoogleSignIn>((ref) => GoogleSignIn.instance);

/// Provider für die SharedPreferences Instanz.
/// WICHTIG: Dieser Provider wird in main.dart mit einem override initialisiert.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  // Wirft einen Fehler, wenn er nicht überschrieben wird. Das stellt sicher,
  // dass SharedPreferences initialisiert ist, bevor die App startet.
  throw UnimplementedError('SharedPreferencesProvider wurde nicht überschrieben');
});

/// Provider für unsere FirestoreDataSource.
final firestoreDataSourceProvider = Provider<FirestoreDataSource>((ref) {
  return FirestoreDataSourceImpl(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
    ref.watch(googleSignInProvider),
  );
});

/// Provider für unsere StorageDataSource (für lokale Einstellungen).
final storageDataSourceProvider = Provider<StorageDataSource>((ref) {
  return StorageDataSourceImpl(ref.watch(sharedPreferencesProvider));
});

//==============================================================================
// SCHICHT 2: REPOSITORY PROVIDERS
// Diese Provider stellen die Implementierungen der Repository-Verträge bereit.
//==============================================================================

/// Provider für das AuthRepository.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.watch(firestoreDataSourceProvider));
});

/// Provider für das SettingsRepository.
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return impl.SettingsRepositoryImpl(ref.watch(sharedPreferencesProvider));
});

/// Provider für das WorkRepository.
/// Dieser ist besonders: Er ist nur gültig, wenn ein Benutzer angemeldet ist,
/// da er die userId benötigt.
final workRepositoryProvider = Provider<WorkRepository>((ref) {
  // Lausche auf den Anmeldestatus.
  final authState = ref.watch(authStateProvider);
  final userId = authState.valueOrNull?.id;

  // Wenn kein Benutzer angemeldet ist, kann das Repository nicht funktionieren.
  if (userId == null) {
    throw Exception('Benutzer nicht angemeldet. WorkRepository kann nicht erstellt werden.');
  }

  return WorkRepositoryImpl(
    dataSource: ref.watch(firestoreDataSourceProvider),
    userId: userId,
  );
});

//==============================================================================
// SCHICHT 3: USE CASE PROVIDERS
// Diese Provider stellen Instanzen der Use Cases bereit. ViewModels verwenden diese.
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

// --- Work Entry Use Cases ---
final getTodayWorkEntryUseCaseProvider = Provider(
      (ref) => GetTodayWorkEntry(ref.watch(workRepositoryProvider)),
);

final saveWorkEntryUseCaseProvider = Provider(
      (ref) => SaveWorkEntry(ref.watch(workRepositoryProvider)),
);

final startOrStopTimerUseCaseProvider = Provider(
      (ref) => StartOrStopTimer(ref.watch(workRepositoryProvider)),
);

final getWorkEntriesForMonthUseCaseProvider = Provider(
      (ref) => GetWorkEntriesForMonth(ref.watch(workRepositoryProvider)),
);

final toggleBreakUseCaseProvider = Provider((ref) => ToggleBreak(ref.watch(workRepositoryProvider)));