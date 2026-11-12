import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Prüft typbasiert, ob [error] ein vorübergehender Netzwerkfehler ist
/// (Verbindungsabbruch, Offline, Timeout). Solche Fehler sind kein App-Fehler
/// und sollen nicht als Crashlytics-Non-Fatal gemeldet werden (#506).
///
/// `package:http` verpackt `SocketException`s in eine `ClientException`, deren
/// Typ den Fehler nicht preisgibt – nur die Meldung enthält die Ursache
/// (z. B. `ClientException with SocketException: Software caused connection
/// abort`). Andere `ClientException`s gelten nicht als transient.
bool isTransientNetworkError(Object error) {
  if (error is SocketException || error is TimeoutException) return true;
  if (error is http.ClientException) {
    return error.message.contains('SocketException');
  }
  return false;
}
