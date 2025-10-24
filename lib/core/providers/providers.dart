import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/version_service.dart';
import '../../data/datasources/remote/firestore_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/repositories/settings_repository_impl.dart' as impl;
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/usecases/delete_account.dart';
import '../../domain/usecases/get_auth_state_changes.dart';
import '../../domain/usecases/get_theme_mode.dart';
import '../../domain/usecases/set_theme_mode.dart';
import '../../domain/usecases/sign_in_with_google.dart';
import '../../domain/usecases/sign_out.dart';

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

//==============================================================================
// SERVICES
//==============================================================================

final versionServiceProvider = Provider<VersionService>((ref) {
  return VersionService(ref.watch(firestoreProvider));
});

//==============================================================================
// SCHICHT 2: REPOSITORY PROVIDERS
//==============================================================================

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.watch(firestoreDataSourceProvider));
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final userId = ref.watch(firebaseAuthProvider).currentUser?.uid;
  // Verwende immer SettingsRepositoryImpl mit SharedPreferences
  // Theme-Einstellungen sollen auch ohne Login funktionieren
  return impl.SettingsRepositoryImpl(
    ref.watch(sharedPreferencesProvider),
    ref.watch(firestoreDataSourceProvider),
    userId ?? 'local', // Fallback zu 'local' wenn nicht eingeloggt
  );
});

// NOTE: workRepositoryProvider and overtimeRepositoryProvider are defined in
// dashboard_view_model.dart with hybrid implementation (automatic fallback between Firebase and Local)

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
final deleteAccountUseCaseProvider = Provider(
  (ref) => DeleteAccount(ref.watch(authRepositoryProvider)),
);

// --- Settings Use Cases ---
final getThemeModeUseCaseProvider = Provider(
  (ref) => GetThemeMode(ref.watch(settingsRepositoryProvider)),
);
final setThemeModeUseCaseProvider = Provider(
  (ref) => SetThemeMode(ref.watch(settingsRepositoryProvider)),
);

// NOTE: Overtime and Work Entry use case providers are defined in
// dashboard_view_model.dart to work with the hybrid repository implementation
