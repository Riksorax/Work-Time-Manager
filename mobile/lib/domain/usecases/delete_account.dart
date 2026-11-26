import '../../core/utils/api_errors.dart';
import '../../core/utils/logger.dart';
import '../repositories/auth_repository.dart';
import '../repositories/local_user_data_repository.dart';

/// Use Case für das Löschen eines Accounts.
///
/// Nach dem **erfolgreichen** Löschen entfernt er die lokalen Daten des
/// Nutzers ([LocalUserDataRepository], #581). Scheitert das Löschen (Fehler)
/// oder bricht der Nutzer die erneute Anmeldung ab (der Nutzer ist danach
/// noch angemeldet), bleibt lokal alles stehen.
class DeleteAccount {
  final AuthRepository _repository;
  final LocalUserDataRepository? _localUserData;
  final String? Function() _currentUserId;

  DeleteAccount(
    this._repository, {
    LocalUserDataRepository? localUserData,
    String? Function()? currentUserId,
  })  : _localUserData = localUserData,
        _currentUserId = currentUserId ?? _none;

  static String? _none() => null;

  /// Führt die Account-Löschung durch.
  Future<void> call() async {
    final userId = _currentUserId();
    await _repository.deleteAccount();

    final localUserData = _localUserData;
    if (userId == null || localUserData == null) return;
    // Noch derselbe Nutzer angemeldet: nicht gelöscht (z. B. erneute
    // Anmeldung abgebrochen) - lokale Daten bleiben.
    if (_currentUserId() == userId) return;
    try {
      await localUserData.removeUserData(userId);
    } catch (e, stackTrace) {
      // Das Konto ist gelöscht; ein Fehler beim Aufräumen ist kein
      // Löschfehler für den Nutzer.
      logger.e('[DeleteAccount] Lokale Daten nicht entfernt (${errorLabel(e)})',
          stackTrace: stackTrace);
    }
  }
}
