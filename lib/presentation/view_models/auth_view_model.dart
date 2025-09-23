import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../domain/entities/user_entity.dart';

/// Ein StreamProvider, der die App über Änderungen des Anmeldestatus informiert.
/// Die UI lauscht auf diesen Provider, um zu wissen, ob ein Benutzer angemeldet ist.
final authStateProvider = StreamProvider<UserEntity?>((ref) {
  final getAuthStateChanges = ref.watch(getAuthStateChangesUseCaseProvider);
  return getAuthStateChanges();
});

/// Provider für die Sign-In-Aktion.
final signInWithGoogleProvider = Provider((ref) {
  return ref.watch(signInWithGoogleUseCaseProvider);
});

/// Provider für die Sign-Out-Aktion.
final signOutProvider = Provider((ref) {
  return ref.watch(signOutUseCaseProvider);
});

/// Provider für die Account-Löschen-Aktion.
final deleteAccountProvider = Provider((ref) {
  return ref.watch(deleteAccountUseCaseProvider);
});
