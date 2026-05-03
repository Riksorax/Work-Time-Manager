import '../../core/providers/providers.dart';

// Re-export authStateProvider (generated in providers.dart)
export '../../core/providers/providers.dart' show authStateProvider;

// Aliases for backward compatibility
final signInWithGoogleProvider = signInWithGoogleUseCaseProvider;
final signOutProvider = signOutUseCaseProvider;
final deleteAccountProvider = deleteAccountUseCaseProvider;