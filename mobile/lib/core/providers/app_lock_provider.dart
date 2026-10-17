import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:local_auth/local_auth.dart';

import '../services/app_lock_service.dart';
import '../services/app_lock_store.dart';
import 'clock_provider.dart';

final localAuthProvider =
    Provider<LocalAuthentication>((ref) => LocalAuthentication());

/// Speicher der App-Sperre (siehe #375). Wird in `main.dart` mit dem vor
/// `runApp` geladenen Store überschrieben (Ausnahme zur Regel „Prefs nur über
/// den Override“, gilt nur für Secrets); der Default ist ein leerer
/// In-Memory-Store (Web, Tests ohne Override).
final appLockStoreProvider =
    Provider<AppLockStore>((ref) => AppLockStore.inMemory());

final appLockServiceProvider = Provider<AppLockService>((ref) {
  return AppLockService(
    store: ref.watch(appLockStoreProvider),
    localAuth: ref.watch(localAuthProvider),
    now: ref.watch(clockProvider),
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
