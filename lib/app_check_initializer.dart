import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

/// AppBootstrap stellt sicher, dass Firebase initialisiert ist
/// und Firebase App Check aktiviert wird (Android-only).
///
/// Verwendung (in main.dart):
///
/// // Variante A: Explizit Provider setzen
/// Future<void> main() async {
///   await AppBootstrap.ensureInitialized(
///     androidProvider: `AndroidProvider.playIntegrity`, // Dev: `AndroidProvider.debug`
///   );
///   runApp(const MyApp());
/// }
///
/// // Variante B: Automatisch je nach Build (Debug/Release)
/// Future<void> main() async {
///   await AppBootstrap.ensureInitializedForEnv();
///   runApp(const MyApp());
/// }
class AppBootstrap {
  static bool _initialized = false;

  /// Initialisiert Firebase und aktiviert App Check.
  /// - androidProvider: Produktion `PlayIntegrity`, Entwicklung `AndroidProvider.debug`.
  /// - autoRefresh: Hält das App-Check-Token automatisch aktuell.
  static Future<void> ensureInitialized({
    AndroidProvider androidProvider = AndroidProvider.playIntegrity,
    bool autoRefresh = true,
  }) async {
    if (_initialized) return;

    WidgetsFlutterBinding.ensureInitialized();

    // Firebase initialisieren (nur wenn noch nicht geschehen)
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }

    // App Check aktivieren (Android-only) mit Fallback für Dev-Installationen
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: androidProvider,
      );
    } catch (e) {
      // Häufige Ursache: Play Integrity schlägt fehl bei Side-Load/Emulator
      if (androidProvider == AndroidProvider.playIntegrity) {
        debugPrint(
          '[AppCheck] Play Integrity Aktivierung fehlgeschlagen. Fallback auf AndroidProvider.debug. '
          'Für Release: über Play (interner Test) installieren.',
        );
        try {
          await FirebaseAppCheck.instance.activate(
            androidProvider: AndroidProvider.debug,
          );
        } catch (_) {
          // Ignorieren; Fehler wird beim ersten Request sichtbar.
        }
      }
    }

    // Token Auto-Refresh aktivieren (empfohlen)
    await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(autoRefresh);

    _initialized = true;
  }

  /// Bequeme Variante: in Debug App Check überspringen, in Release aktivieren.
  static Future<void> ensureInitializedForEnv() async {
    if (kReleaseMode) {
      return ensureInitialized(
        androidProvider: AndroidProvider.playIntegrity,
        autoRefresh: true,
      );
    } else {
      // In Debug: App Check nicht aktivieren, um GMS/Phenotype-Rauschen zu vermeiden
      debugPrint('[AppCheck] Debug-Build erkannt: App Check wird übersprungen.');
      _initialized = true;
      return;
    }
  }
}
