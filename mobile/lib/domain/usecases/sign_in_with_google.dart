import '../repositories/auth_repository.dart';

/// Use Case für den Google Sign-In Prozess.
class SignInWithGoogle {
  final AuthRepository _repository;

  SignInWithGoogle(this._repository);

  /// Startet den Anmeldevorgang.
  Future<void> call() async {
    await _repository.signInWithGoogle();
  }
}
