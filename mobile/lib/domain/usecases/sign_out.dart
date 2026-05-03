import '../repositories/auth_repository.dart';

/// Use Case für den Sign-Out Prozess.
class SignOut {
  final AuthRepository _repository;

  SignOut(this._repository);

  /// Führt den Logout durch.
  Future<void> call() async {
    await _repository.signOut();
  }
}