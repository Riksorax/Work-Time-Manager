import '../repositories/auth_repository.dart';

/// Use Case: bestätigt die Identität des angemeldeten Nutzers erneut (#288).
class Reauthenticate {
  final AuthRepository _repository;

  Reauthenticate(this._repository);

  /// `true` nur bei verifizierter Re-Authentifizierung.
  Future<bool> call() => _repository.reauthenticate();
}
