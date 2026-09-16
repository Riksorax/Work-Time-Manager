import '../entities/weekly_reflection_entity.dart';

/// Repository für Wochen-Reflexionen (siehe #137).
///
/// Anders als [WorkRepository]/[OvertimeRepository] bewusst ohne Local/
/// Hybrid-Fallback für ausgeloggte Nutzer: die Funktion ist ein
/// Premium-Feature und setzt in der UI ohnehin ein Login voraus, bevor das
/// Premium-Gate greift (siehe `WeeklyReportView`).
abstract class WeeklyReflectionRepository {
  Future<WeeklyReflectionEntity?> getReflection(int year, int week);
  Future<void> saveReflection(WeeklyReflectionEntity reflection);
}
