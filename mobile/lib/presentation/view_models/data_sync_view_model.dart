import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart' as core_providers;
import '../../data/repositories/firebase_overtime_repository_impl.dart';
import '../../data/repositories/hybrid_overtime_repository_impl.dart';
import '../../data/repositories/hybrid_work_repository_impl.dart';
import '../../data/services/data_sync_service.dart';

final dataSyncViewModelProvider = Provider<DataSyncViewModel>((ref) => DataSyncViewModel(ref));

/// Ergebnis einer erfolgreich durchgeführten Synchronisation.
class DataSyncResult {
  const DataSyncResult({
    required this.workEntriesSynced,
    required this.overtimeSynced,
    required this.errors,
  });

  final int workEntriesSynced;
  final bool overtimeSynced;
  final List<String> errors;
}

/// Wird geworfen, wenn nichts zu synchronisieren ist: kein eingeloggter
/// Nutzer, oder die Repositories sind (noch) nicht die Hybrid-Variante.
/// Eigener Typ statt einer generischen Exception, damit Aufrufer diesen Fall
/// bei Bedarf von einem echten Sync-Fehler unterscheiden können (siehe
/// Login-Flow in `login_page.dart`, der ihn ohne Fehlermeldung ignoriert).
class SyncNotAvailableException implements Exception {
  const SyncNotAvailableException();

  @override
  String toString() => 'Repositories sind nicht vom Typ Hybrid oder User nicht eingeloggt';
}

/// Synchronisiert lokale Daten (SharedPreferences) mit Firebase - beim Login
/// automatisch und manuell aus den Einstellungen. Kapselt den Zugriff auf
/// die Hybrid-Repositories und `DataSyncService`, damit Screens nicht selbst
/// prüfen müssen, ob und wie synchronisiert werden kann (siehe #294).
class DataSyncViewModel {
  DataSyncViewModel(this._ref);
  final Ref _ref;

  /// Wirft [SyncNotAvailableException], wenn kein Nutzer eingeloggt ist oder
  /// die Repositories nicht die Hybrid-Variante sind. Andere Fehler aus dem
  /// eigentlichen Sync werden unverändert weitergereicht.
  Future<DataSyncResult> syncAll() async {
    final workRepository = _ref.read(core_providers.workRepositoryProvider);
    final overtimeRepository = _ref.read(core_providers.overtimeRepositoryProvider);
    final userId = _ref.read(core_providers.firebaseAuthProvider).currentUser?.uid;

    if (workRepository is! HybridWorkRepositoryImpl ||
        overtimeRepository is! HybridOvertimeRepositoryImpl ||
        userId == null) {
      throw const SyncNotAvailableException();
    }

    // Frisches Firebase-Repository mit der aktuellen userId erstellen - der
    // reguläre Provider kann kurz nach dem Login noch die alte/leere userId
    // tragen.
    final freshFirebaseOvertimeRepo = FirebaseOvertimeRepositoryImpl(
      dataSource: _ref.read(core_providers.firestoreDataSourceProvider),
      userId: userId,
    );

    final raw = await DataSyncService.syncAll(
      localWorkRepository: workRepository.localRepository,
      firebaseWorkRepository: workRepository.firebaseRepository,
      localOvertimeRepository: overtimeRepository.localRepository,
      firebaseOvertimeRepository: freshFirebaseOvertimeRepo,
    );

    return DataSyncResult(
      workEntriesSynced: raw['workEntriesSynced'] as int,
      overtimeSynced: raw['overtimeSynced'] as bool,
      errors: (raw['errors'] as List).cast<String>(),
    );
  }
}
