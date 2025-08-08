import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

/// Use Case, um den Stream der Authentifizierungsstatus-Änderungen zu erhalten.
class GetAuthStateChanges {
  final AuthRepository _repository;

  GetAuthStateChanges(this._repository);

  /// Führt den Use Case aus und gibt den Stream zurück.
  Stream<UserEntity?> call() {
    return _repository.authStateChanges;
  }
}