import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Leitet Log-Einträge ab [Level.warning] zusätzlich als nicht-fatalen Fehler
/// an Firebase Crashlytics weiter. Damit fallen Fehler in Auth-/Sync-Pfaden
/// (z. B. `logger.e(...)` in Repositories/DataSources) zentral auf, statt
/// unbemerkt nur in der lokalen Konsole zu verschwinden (siehe #207).
class _CrashlyticsLogOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    // Crashlytics ist nur auf Android/iOS verfügbar.
    if (kIsWeb || event.level < Level.warning) return;
    try {
      // Vor `Firebase.initializeApp()` (z. B. Timezone-Fallback in main())
      // ist noch keine App registriert – dann nicht versuchen zu melden.
      if (Firebase.apps.isEmpty) return;
      FirebaseCrashlytics.instance.recordError(
        event.origin.error ?? event.origin.message,
        event.origin.stackTrace,
        reason: 'logger.${event.origin.level.name}',
        fatal: false,
      );
    } catch (_) {
      // Logging darf niemals selbst einen Fehler werfen.
    }
  }
}

final logger = Logger(
  // ProductionFilter statt Default (DevelopmentFilter): Ohne das würden
  // Fehler in Release-Builds komplett verschluckt und kämen nie in
  // Crashlytics an – das war genau das Problem hinter #207.
  filter: ProductionFilter(),
  printer: PrettyPrinter(),
  output: MultiOutput([ConsoleOutput(), _CrashlyticsLogOutput()]),
);
