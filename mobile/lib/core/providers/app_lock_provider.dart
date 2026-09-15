import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../services/app_lock_service.dart';
import 'providers.dart';

final localAuthProvider = Provider<LocalAuthentication>((ref) => LocalAuthentication());

final appLockServiceProvider = Provider<AppLockService>((ref) {
  return AppLockService(
    prefs: ref.watch(sharedPreferencesProvider),
    localAuth: ref.watch(localAuthProvider),
  );
});

/// Ob die App aktuell gesperrt ist (siehe #223). Startet gesperrt, wenn die
/// PIN-/Biometrie-Sperre aktiviert und eine PIN hinterlegt ist; wird beim
/// Wechsel in den Hintergrund (`AppLifecycleState.paused`) wieder gesetzt.
/// Auf Web nie aktiv, da der Browser keine vergleichbare native Sperre bietet.
final isAppLockedProvider = StateProvider<bool>((ref) {
  if (kIsWeb) return false;
  final service = ref.watch(appLockServiceProvider);
  return service.isEnabled && service.hasPin;
});
