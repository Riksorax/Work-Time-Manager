import '../../core/utils/api_errors.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/network_error.dart';
import '../../l10n/app_localizations.dart';

/// Text für Nutzer zu [error], nie mit dem Ausnahmetext (#582): bei einem
/// vorübergehenden Netzwerkfehler (Offline, Verbindungsabbruch, Timeout)
/// „Keine Verbindung …“, sonst die allgemeine Meldung [general] der Stelle.
String userErrorMessage(AppLocalizations l10n, Object error,
        {required String general}) =>
    isTransientNetworkError(error) ? l10n.errorNoConnectionMessage : general;

/// Schreibt einen Fehler, den der Nutzer als Meldung sieht, ins Log (#582).
///
/// Ohne Ausnahmetext (der kann URLs, E-Mail-Adressen oder Profilnamen
/// enthalten): nur [errorLabel]. Erwartbare Fehler ([isExpectedLoadFailure]:
/// Netzwerk, abgemeldet) sind kein App-Fehler und gehen nur als `logger.i`
/// ins Log; alle anderen als `logger.e` (Crashlytics) mit [stackTrace].
void logUserFacingError(String tag, Object error, [StackTrace? stackTrace]) {
  if (isExpectedLoadFailure(error)) {
    logger.i('$tag (${errorLabel(error)})');
  } else {
    logger.e('$tag (${errorLabel(error)})', stackTrace: stackTrace);
  }
}
