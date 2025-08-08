import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../domain/entities/work_entry_entity.dart';

final dashboardViewModelProvider =
AsyncNotifierProvider<DashboardViewModel, WorkEntryEntity>(
  DashboardViewModel.new,
);

class DashboardViewModel extends AsyncNotifier<WorkEntryEntity> {
  @override
  Future<WorkEntryEntity> build() async {
    // Initiales Laden der Daten für heute.
    final getTodayWorkEntry = ref.watch(getTodayWorkEntryUseCaseProvider);
    return await getTodayWorkEntry();
  }

  /// Startet oder stoppt den Haupt-Timer.
  Future<void> startOrStopTimer() async {
    final startOrStopTimerUseCase = ref.read(startOrStopTimerUseCaseProvider);

    // Setze den Ladezustand, während die Aktion ausgeführt wird.
    state = const AsyncValue.loading();

    // Führe die Aktion aus und aktualisiere den Zustand mit dem Ergebnis.
    state = await AsyncValue.guard(() async {
      // 'state.value' ist der vorherige Zustand. Es ist wichtig, einen gültigen
      // vorherigen Zustand zu haben. 'build' stellt dies sicher.
      final previousEntry = await future;
      return await startOrStopTimerUseCase(previousEntry);
    });
  }

  /// Startet oder stoppt eine Pause.
  Future<void> toggleBreak() async {
    // Hole den Use Case aus dem Provider.
    final toggleBreakUseCase = ref.read(toggleBreakUseCaseProvider);

    // Setze den Ladezustand, während die Aktion ausgeführt wird.
    state = const AsyncValue.loading();

    // Führe die Aktion aus und aktualisiere den Zustand mit dem Ergebnis.
    state = await AsyncValue.guard(() async {
      final previousEntry = await future;
      return await toggleBreakUseCase(previousEntry);
    });
  }

// Hier würden weitere Methoden wie addBreak, setManualOvertime etc. folgen.
}