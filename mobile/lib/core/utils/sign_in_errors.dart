import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:google_sign_in/google_sign_in.dart';

import 'network_error.dart';

/// Der Nutzer hat die Google-Anmeldung selbst abgebrochen (Kontoauswahl bzw.
/// Popup geschlossen). Das ist kein Fehler: keine Meldung, kein `logger.e`
/// (#582).
bool isSignInCanceled(Object error) {
  if (error is GoogleSignInException) {
    return error.code == GoogleSignInExceptionCode.canceled;
  }
  if (error is firebase.FirebaseAuthException) {
    // Web: Popup geschlossen bzw. durch ein zweites Popup ersetzt.
    return error.code == 'popup-closed-by-user' ||
        error.code == 'cancelled-popup-request';
  }
  return false;
}

/// Netzwerkfehler bei der Anmeldung: wie [isTransientNetworkError], dazu
/// der Firebase-Code `network-request-failed` (#582).
bool isSignInNetworkError(Object error) =>
    isTransientNetworkError(error) ||
    (error is firebase.FirebaseAuthException &&
        error.code == 'network-request-failed');
