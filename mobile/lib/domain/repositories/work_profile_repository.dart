import '../entities/work_profile_entity.dart';

/// Verwaltung zusätzlicher Arbeitszeit-Profile (siehe #138). Wie
/// [WeeklyReflectionRepository] bewusst ohne Local/Hybrid-Fallback - die
/// Funktion ist ein Premium-Feature und setzt in der UI ein Login voraus.
///
/// Löschen ist bewusst nicht Teil dieses Repositories (siehe PR-Beschreibung
/// #138) - Firestore-Subcollections lassen sich clientseitig nicht ohne
/// Kenntnis aller enthaltenen Dokumente rekursiv löschen, das ist als
/// separater Folge-Task vorgesehen.
abstract class WorkProfileRepository {
  /// Zusätzliche Profile des Nutzers (ohne das stets vorhandene
  /// [WorkProfileEntity.defaultProfile]).
  Future<List<WorkProfileEntity>> getAdditionalProfiles();

  /// Legt ein neues zusätzliches Profil an und gibt es zurück.
  Future<WorkProfileEntity> addProfile(String name);
}
