/// Lokal gespeicherte Daten eines angemeldeten Nutzers (#581).
///
/// Bündelt das Aufräumen nach dem Löschen des Kontos an einer Stelle: alle
/// nutzer- und profilbezogenen Werte des Geräts (Einstellungen je Profil,
/// gemerkter Saldo, Arbeitsort-Verlauf, gemerktes Profil). Gast-Daten und
/// geräteweite Einstellungen bleiben unberührt.
abstract class LocalUserDataRepository {
  /// Entfernt alle lokalen Werte des Nutzers [userId] (alle Profile).
  Future<void> removeUserData(String userId);
}
