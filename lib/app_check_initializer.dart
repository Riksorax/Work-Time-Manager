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
///     androidProvider: AndroidProvider.playIntegrity, // Dev: AndroidProvider.debug
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
  /// - androidProvider: Produktion PlayIntegrity, Entwicklung AndroidProvider.debug.
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

    // App Check aktivieren (Android-only)
    await FirebaseAppCheck.instance.activate(
      androidProvider: androidProvider,
    );

    // Token Auto-Refresh aktivieren (empfohlen)
    await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(autoRefresh);

    _initialized = true;
  }

  /// Bequeme Variante: wählt automatisch Debug- oder Produktions-Provider.
  /// - Debug: AndroidProvider.debug
  /// - Release: AndroidProvider.playIntegrity
  static Future<void> ensureInitializedForEnv() async {
    return ensureInitialized(
      androidProvider: kReleaseMode ? AndroidProvider.playIntegrity : AndroidProvider.debug,
      autoRefresh: true,
    );
  }
}
