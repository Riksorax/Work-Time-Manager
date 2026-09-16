import '../entities/work_profile_entity.dart';

/// Verwaltung zusätzlicher Arbeitszeit-Profile (siehe #138). Wie
/// [WeeklyReflectionRepository] bewusst ohne Local/Hybrid-Fallback - die
/// Funktion ist ein Premium-Feature und setzt in der UI ein Login voraus.
abstract class WorkProfileRepository {
  /// Zusätzliche Profile des Nutzers (ohne das stets vorhandene
  /// [WorkProfileEntity.defaultProfile]).
  Future<List<WorkProfileEntity>> getAdditionalProfiles();

  /// Legt ein neues zusätzliches Profil an und gibt es zurück.
  Future<WorkProfileEntity> addProfile(String name);

  /// Löscht ein zusätzliches Profil unwiderruflich inkl. aller zugehörigen
  /// Arbeitseinträge, Überstunden und Einstellungen (siehe #238). Das
  /// Standard-Profil kann nicht über diese Methode gelöscht werden - das
  /// muss aufrufseitig verhindert werden.
  Future<void> deleteProfile(String profileId);
}
