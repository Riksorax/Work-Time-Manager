import '../repositories/work_repository.dart';
import '../repositories/overtime_repository.dart';
import '../../data/repositories/local_work_repository_impl.dart';
import '../../data/repositories/local_overtime_repository_impl.dart';

/// Service zum Synchronisieren lokaler Daten mit Firebase
class DataSyncService {
  /// Synchronisiert alle lokalen Arbeitseinträge zu Firebase
  ///
  /// Returns: Anzahl der synchronisierten Einträge
  static Future<int> syncWorkEntries({
    required WorkRepository localRepository,
    required WorkRepository firebaseRepository,
  }) async {
    print('[DataSyncService] Starte Sync der Arbeitseinträge...');

    if (localRepository is! LocalWorkRepositoryImpl) {
      print('[DataSyncService] Local Repository ist nicht vom Typ LocalWorkRepositoryImpl');
      return 0;
    }

    try {
      // Hole alle lokalen Einträge
      final localEntries = await localRepository.getAllLocalEntries();

      if (localEntries.isEmpty) {
        print('[DataSyncService] Keine lokalen Einträge zum Synchronisieren');
        return 0;
      }

      print('[DataSyncService] Gefunden: ${localEntries.length} lokale Einträge');

      // Synchronisiere jeden Eintrag zu Firebase
      int syncedCount = 0;
      for (final entry in localEntries) {
        try {
          await firebaseRepository.saveWorkEntry(entry);
          syncedCount++;
          print('[DataSyncService] Synced: ${entry.date}');
        } catch (e) {
          print('[DataSyncService] Fehler beim Sync von ${entry.date}: $e');
          // Weiter mit nächstem Eintrag
        }
      }

      print('[DataSyncService] Erfolgreich synchronisiert: $syncedCount/${localEntries.length}');

      // Wenn alle erfolgreich, lösche lokale Daten
      if (syncedCount == localEntries.length) {
        await localRepository.clearAllLocalEntries();
        print('[DataSyncService] Lokale Einträge gelöscht nach erfolgreicher Sync');
      }

      return syncedCount;
    } catch (e) {
      print('[DataSyncService] Fehler beim Sync: $e');
      rethrow;
    }
  }

  /// Synchronisiert die Überstunden-Bilanz zu Firebase
  ///
  /// Returns: true wenn erfolgreich
  static Future<bool> syncOvertime({
    required OvertimeRepository localRepository,
    required OvertimeRepository firebaseRepository,
  }) async {
    print('[DataSyncService] Starte Sync der Überstunden...');

    try {
      // Hole lokale Überstunden
      final localOvertime = localRepository.getOvertime();

      if (localOvertime == Duration.zero) {
        print('[DataSyncService] Keine lokalen Überstunden zum Synchronisieren');
        return true;
      }

      print('[DataSyncService] Lokale Überstunden: ${localOvertime.inMinutes} Min');

      // Hole Firebase Überstunden
      final firebaseOvertime = firebaseRepository.getOvertime();
      print('[DataSyncService] Firebase Überstunden: ${firebaseOvertime.inMinutes} Min');

      // Merge: Nehme den höheren Wert (oder addiere beide?)
      // Hier: Addieren, falls beide Werte vorhanden
      final totalOvertime = firebaseOvertime + localOvertime;

      // Speichere zu Firebase
      await firebaseRepository.saveOvertime(totalOvertime);
      print('[DataSyncService] Überstunden synchronisiert: ${totalOvertime.inMinutes} Min');

      // Lösche lokale Überstunden nur wenn Firebase erfolgreich
      if (localRepository is LocalOvertimeRepositoryImpl) {
        await localRepository.saveOvertime(Duration.zero);
        print('[DataSyncService] Lokale Überstunden zurückgesetzt');
      }

      return true;
    } catch (e) {
      print('[DataSyncService] Fehler beim Sync der Überstunden: $e');
      return false;
    }
  }

  /// Führt eine komplette Synchronisation durch
  ///
  /// Returns: Map mit Statistiken
  static Future<Map<String, dynamic>> syncAll({
    required WorkRepository localWorkRepository,
    required WorkRepository firebaseWorkRepository,
    required OvertimeRepository localOvertimeRepository,
    required OvertimeRepository firebaseOvertimeRepository,
  }) async {
    print('[DataSyncService] ═══ Starte vollständige Synchronisation ═══');

    final result = <String, dynamic>{
      'workEntriesSynced': 0,
      'overtimeSynced': false,
      'errors': <String>[],
    };

    // Sync Arbeitseinträge
    try {
      final syncedCount = await syncWorkEntries(
        localRepository: localWorkRepository,
        firebaseRepository: firebaseWorkRepository,
      );
      result['workEntriesSynced'] = syncedCount;
    } catch (e) {
      result['errors'].add('Arbeitseinträge: $e');
    }

    // Sync Überstunden
    try {
      final overtimeSynced = await syncOvertime(
        localRepository: localOvertimeRepository,
        firebaseRepository: firebaseOvertimeRepository,
      );
      result['overtimeSynced'] = overtimeSynced;
    } catch (e) {
      result['errors'].add('Überstunden: $e');
    }

    print('[DataSyncService] ═══ Synchronisation abgeschlossen ═══');
    print('[DataSyncService] Arbeitseinträge: ${result['workEntriesSynced']}');
    print('[DataSyncService] Überstunden: ${result['overtimeSynced']}');
    if ((result['errors'] as List).isNotEmpty) {
      print('[DataSyncService] Fehler: ${result['errors']}');
    }

    return result;
  }
}
