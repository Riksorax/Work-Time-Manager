import 'network_error.dart';

/// Die Backend-API hat mit einem anderen Status als erwartet geantwortet.
///
/// Der Status steht im Typ-Text ([toString]) und damit in Log-Zeilen, die nur
/// den Fehler nennen. Der Antwort-Body gehört nicht hinein (kann Nutzerdaten
/// enthalten).
class ApiException implements Exception {
  const ApiException(this.operation, this.statusCode);

  /// Name des fehlgeschlagenen Aufrufs, z. B. `getWorkEntriesForMonth`.
  final String operation;
  final int statusCode;

  @override
  String toString() => 'API $operation fehlgeschlagen ($statusCode)';
}

/// Ein API-Aufruf wurde gestartet, obwohl niemand angemeldet ist.
///
/// Das passiert kurz nach dem Abmelden oder Löschen des Kontos: Firebase hat
/// den Nutzer schon entfernt, der Auth-Status in der Oberfläche zieht erst
/// einen Moment später nach. Der Aufruf wird dann nicht abgeschickt; ohne
/// Token würde das Backend ohnehin mit 401 antworten (#522).
class NotSignedInException implements Exception {
  const NotSignedInException(this.operation);

  final String operation;

  @override
  String toString() => 'API $operation ohne angemeldeten Nutzer';
}

/// Fehler beim **Laden**, die kein App-Fehler sind und nicht als
/// Crashlytics-Non-Fatal gemeldet werden sollen: vorübergehende Netzwerkfehler
/// (#506) und Aufrufe ohne angemeldeten Nutzer (#522). Der Fehlerzustand in
/// der Oberfläche bleibt davon unberührt.
bool isExpectedLoadFailure(Object error) =>
    error is NotSignedInException || isTransientNetworkError(error);

/// Kurzbezeichnung für Log-Zeilen ohne Nutzerdaten: bei [ApiException] mit
/// Status (`ApiException(503)`), sonst der Laufzeittyp.
String errorLabel(Object error) => error is ApiException
    ? 'ApiException(${error.statusCode})'
    : '${error.runtimeType}';
