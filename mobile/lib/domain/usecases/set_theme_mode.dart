import '../entities/app_theme_mode.dart';
import '../repositories/settings_repository.dart';

/// Use Case zum Setzen des Theme-Modus.
class SetThemeMode {
  final SettingsRepository _repository;

  SetThemeMode(this._repository);

  Future<void> call(AppThemeMode mode) async {
    await _repository.setThemeMode(mode);
  }
}
