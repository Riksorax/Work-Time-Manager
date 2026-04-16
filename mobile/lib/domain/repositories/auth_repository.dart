import '../entities/user_entity.dart';

/// Die Schnittstelle (der Vertrag) für alle Authentifizierungsoperationen.
///
/// Dieses Repository abstrahiert die Herkunft der Benutzerdaten.
/// Die Domain-Schicht weiß nicht, ob die Authentifizierung über Firebase,
/// einen eigenen Server oder einen anderen Dienst erfolgt.
abstract class AuthRepository {
  /// Ein Stream, der die App über Änderungen des Authentifizierungsstatus informiert.
  ///
  /// Gibt eine UserEntity zurück, wenn ein Benutzer angemeldet ist,
  /// und null, wenn kein Benutzer angemeldet ist.
  /// Dies ist der primäre Mechanismus, um die UI reaktiv auf Login/Logout
  /// reagieren zu lassen.
  Stream<UserEntity?> get authStateChanges;

  /// Startet den Anmeldevorgang mit Google.
  ///
  /// Wirft eine Exception, wenn der Anmeldevorgang fehlschlägt oder
  /// vom Benutzer abgebrochen wird.
  Future<void> signInWithGoogle();

  /// Meldet den aktuellen Benutzer ab.
  Future<void> signOut();

  /// Löscht den Account des aktuellen Benutzers.
  Future<void> deleteAccount();
}