import '../repositories/auth_repository.dart';

/// Use Case für das Löschen eines Accounts.
class DeleteAccount {
  final AuthRepository _repository;

  DeleteAccount(this._repository);

  /// Führt die Account-Löschung durch.
  Future<void> call() async {
    await _repository.deleteAccount();
  }
}
