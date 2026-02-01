import 'package:flutter_work_time/core/utils/logger.dart';

import '../repositories/work_repository.dart';
import '../repositories/overtime_repository.dart';
import '../../data/repositories/local_work_repository_impl.dart';
import '../../data/repositories/local_overtime_repository_impl.dart';
import '../../data/repositories/firebase_overtime_repository_impl.dart';

/// Service zum Synchronisieren lokaler Daten mit Firebase
class DataSyncService {
  /// Synchronisiert alle lokalen Arbeitseinträge zu Firebase
  ///
  /// Returns: Anzahl der synchronisierten Einträge
  static Future<int> syncWorkEntries({
    required WorkRepository localRepository,
    required WorkRepository firebaseRepository,
  }) async {
    logger.i('[DataSyncService] Starte Sync der Arbeitseinträge...');

    if (localRepository is! LocalWorkRepositoryImpl) {
      logger.w('[DataSyncService] Local Repository ist nicht vom Typ LocalWorkRepositoryImpl');
      return 0;
    }

    try {
      // Hole alle lokalen Einträge
      final localEntries = await localRepository.getAllLocalEntries();

      if (localEntries.isEmpty) {
        logger.i('[DataSyncService] Keine lokalen Einträge zum Synchronisieren');
        return 0;
      }

      logger.i('[DataSyncService] Gefunden: ${localEntries.length} lokale Einträge');

      // Synchronisiere jeden Eintrag zu Firebase
      int syncedCount = 0;
      for (final entry in localEntries) {
        try {
          await firebaseRepository.saveWorkEntry(entry);
          syncedCount++;
          logger.i('[DataSyncService] Synced: ${entry.date}');
        } catch (e) {
          logger.e('[DataSyncService] Fehler beim Sync von ${entry.date}: $e');
          // Weiter mit nächstem Eintrag
        }
      }

      logger.i('[DataSyncService] Erfolgreich synchronisiert: $syncedCount/${localEntries.length}');

      // Wenn alle erfolgreich, lösche lokale Daten
      if (syncedCount == localEntries.length) {
        await localRepository.clearAllLocalEntries();
        logger.i('[DataSyncService] Lokale Einträge gelöscht nach erfolgreicher Sync');
      }

      return syncedCount;
    } catch (e) {
      logger.e('[DataSyncService] Fehler beim Sync: $e');
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
    logger.i('[DataSyncService] Starte Sync der Überstunden...');

    try {
      // Hole lokale Überstunden
      final localOvertime = localRepository.getOvertime();
      final localLastUpdate = localRepository.getLastUpdateDate();

      logger.i('[DataSyncService] Lokale Überstunden: ${localOvertime.inMinutes} Min');

      // Hole Firebase Überstunden - WICHTIG: Async laden für korrekte Werte!
      Duration firebaseOvertime;
      DateTime? firebaseLastUpdate;

      if (firebaseRepository is FirebaseOvertimeRepositoryImpl) {
        // Explizit von Firestore laden (nicht aus leerem Cache)
        firebaseOvertime = await firebaseRepository.loadOvertimeAsync();
        firebaseLastUpdate = await firebaseRepository.loadLastUpdateAsync();
        logger.i('[DataSyncService] Firebase Überstunden (async geladen): ${firebaseOvertime.inMinutes} Min');
      } else {
        firebaseOvertime = firebaseRepository.getOvertime();
        firebaseLastUpdate = firebaseRepository.getLastUpdateDate();
        logger.i('[DataSyncService] Firebase Überstunden: ${firebaseOvertime.inMinutes} Min');
      }

      // Entscheide welche Daten verwendet werden sollen
      // Firebase ist die Quelle der Wahrheit, außer wenn:
      // 1. Firebase ist leer (erster Sync) ODER
      // 2. Lokale Daten sind neuer als Firebase
      bool useLocalData = false;

      if (firebaseOvertime == Duration.zero && localOvertime != Duration.zero) {
        // Firebase leer, lokale Daten vorhanden → lokale verwenden
        useLocalData = true;
        logger.i('[DataSyncService] Firebase leer, verwende lokale Überstunden');
      } else if (localLastUpdate != null && firebaseLastUpdate != null) {
        // Beide haben Daten, vergleiche Zeitstempel
        if (localLastUpdate.isAfter(firebaseLastUpdate)) {
          useLocalData = true;
          logger.i('[DataSyncService] Lokale Daten sind neuer, verwende lokale Überstunden');
        }
      } else if (localOvertime != Duration.zero && firebaseOvertime == Duration.zero) {
        useLocalData = true;
      }

      if (useLocalData) {
        // Lokale Daten zu Firebase synchronisieren
        await firebaseRepository.saveOvertime(localOvertime);
        if (localLastUpdate != null) {
          await firebaseRepository.saveLastUpdateDate(localLastUpdate);
        }
        logger.i('[DataSyncService] Überstunden zu Firebase synchronisiert: ${localOvertime.inMinutes} Min');
      } else {
        logger.i('[DataSyncService] Firebase Überstunden werden beibehalten: ${firebaseOvertime.inMinutes} Min');
      }

      // Lösche lokale Überstunden nach erfolgreicher Sync
      if (localRepository is LocalOvertimeRepositoryImpl) {
        await localRepository.saveOvertime(Duration.zero);
        await localRepository.saveLastUpdateDate(DateTime.fromMillisecondsSinceEpoch(0));
        logger.i('[DataSyncService] Lokale Überstunden zurückgesetzt');
      }

      return true;
    } catch (e) {
      logger.e('[DataSyncService] Fehler beim Sync der Überstunden: $e');
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
    logger.i('[DataSyncService] ═══ Starte vollständige Synchronisation ═══');

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

    logger.i('[DataSyncService] ═══ Synchronisation abgeschlossen ═══');
    logger.i('[DataSyncService] Arbeitseinträge: ${result['workEntriesSynced']}');
    logger.i('[DataSyncService] Überstunden: ${result['overtimeSynced']}');
    if ((result['errors'] as List).isNotEmpty) {
      logger.w('[DataSyncService] Fehler: ${result['errors']}');
    }

    return result;
  }
}
