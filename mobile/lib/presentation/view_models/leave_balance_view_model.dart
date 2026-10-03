import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_work_time/core/utils/logger.dart';

import '../../core/providers/providers.dart' as core_providers;
import '../../domain/entities/work_entry_entity.dart';
import '../../domain/utils/leave_balance_utils.dart';
import '../state/leave_balance_state.dart';

/// Liefert "jetzt" - im Test überschreibbar, damit das Jahr nicht vom
/// aktuellen Datum abhängt.
final leaveBalanceNowProvider =
    Provider<DateTime Function()>((ref) => DateTime.now);

final leaveBalanceViewModelProvider =
    NotifierProvider<LeaveBalanceViewModel, LeaveBalanceState>(
        LeaveBalanceViewModel.new);

/// Berechnet den Resturlaub des laufenden Kalenderjahres offline aus den
/// Arbeitseinträgen (12 Monats-Abfragen über das Hybrid-Repository) und dem
/// Urlaubsanspruch aus den Einstellungen (siehe #278).
///
/// Wird nach Änderungen an Einträgen/Anspruch per `ref.invalidate` neu
/// geladen; das Jahr wird bei jedem Laden neu bestimmt.
class LeaveBalanceViewModel extends Notifier<LeaveBalanceState> {
  LeaveBalance? _last;

  @override
  LeaveBalanceState build() {
    // Profil-/Login-Wechsel erzeugt neue Repository-Instanzen -> Neuladen.
    ref.watch(core_providers.workRepositoryProvider);
    ref.watch(core_providers.settingsRepositoryProvider);
    Future.microtask(_load);
    return LeaveBalanceState(isLoading: true, balance: _last);
  }

  /// Lädt die Bilanz erneut (z. B. "Erneut versuchen" in der Fehleransicht).
  Future<void> reload() async {
    state = LeaveBalanceState(isLoading: true, balance: _last);
    await _load();
  }

  Future<void> _load() async {
    try {
      final year = ref.read(leaveBalanceNowProvider)().year;
      final workRepository = ref.read(core_providers.workRepositoryProvider);
      final entitlement = ref
          .read(core_providers.settingsRepositoryProvider)
          .getVacationDaysPerYear();
      final perMonth = await Future.wait(
          List<Future<List<WorkEntryEntity>>>.generate(
              12, (i) => workRepository.getWorkEntriesForMonth(year, i + 1)));
      if (!ref.mounted) return;
      _last = calculateLeaveBalance(
          perMonth.expand((e) => e).toList(), year, entitlement);
      state = LeaveBalanceState(balance: _last);
    } catch (e, st) {
      logger.e('[LeaveBalanceViewModel] Fehler beim Laden: $e', stackTrace: st);
      if (!ref.mounted) return;
      state = const LeaveBalanceState(hasError: true);
    }
  }
}
