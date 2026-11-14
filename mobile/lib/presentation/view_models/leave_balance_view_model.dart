import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_work_time/core/utils/logger.dart';
import 'package:flutter_work_time/core/utils/api_errors.dart';

import '../../core/providers/providers.dart' as core_providers;
import '../../core/providers/today_provider.dart';
import '../../domain/entities/work_entry_entity.dart';
import '../../domain/utils/leave_balance_utils.dart';
import '../state/leave_balance_state.dart';

final leaveBalanceViewModelProvider =
    NotifierProvider<LeaveBalanceViewModel, LeaveBalanceState>(
        LeaveBalanceViewModel.new);

/// Resturlaub des laufenden Kalenderjahres (siehe #278).
///
/// - **Angemeldet:** ein Aufruf `GET /api/reports/yearly/{year}` (#535); das
///   Backend zählt genommene Urlaubs- und Krankheitstage. Der Anspruch kommt
///   aus der Antwort. Weicht er vom lokal gespeicherten Anspruch ab, gilt der
///   lokale: Die Einstellungen speichern ihn sofort lokal und schicken ihn erst
///   danach ohne Warten an den Server (`SettingsRepositoryImpl`), ein direkt
///   nach dem Speichern geladener Bericht kann also noch den alten Wert
///   tragen. Der Rest ist dann lokaler Anspruch minus genommene Tage.
/// - **Gast:** lokal aus den Arbeitseinträgen (12 Monats-Abfragen über das
///   Hybrid-Repository) und dem Anspruch aus den Einstellungen.
///
/// Wird nach Änderungen an Einträgen/Anspruch per `ref.invalidate` neu
/// geladen; Profil- und Login-Wechsel bauen das ViewModel über die
/// beobachteten Provider neu. Das Jahr kommt aus [todayProvider]. Beim
/// Jahreswechsel (#387) wird die Vorjahres-Bilanz verworfen und neu geladen
/// (Ladezustand statt falschem Resturlaub); Tageswechsel im selben Jahr lösen
/// nichts aus.
class LeaveBalanceViewModel extends Notifier<LeaveBalanceState> {
  LeaveBalance? _last;

  /// Zählt Neuaufbau und Neuladen; ein überholter Ladelauf (z. B. Antwort für
  /// das vorherige Profil) verwirft sein Ergebnis.
  int _gen = 0;

  @override
  LeaveBalanceState build() {
    _gen++;
    // Profil-/Login-Wechsel erzeugt neue Repository-Instanzen -> Neuladen.
    ref.watch(core_providers.workRepositoryProvider);
    ref.watch(core_providers.settingsRepositoryProvider);
    // listen statt watch: watch würde den Notifier an jedem Tag neu bauen
    // (Abfragen, Zustandsverlust).
    ref.listen<DateTime>(todayProvider, (previous, next) {
      if (previous != null && previous.year != next.year) {
        _last = null;
        reload();
      }
    });
    final year = ref.read(todayProvider).year;
    if (_last?.year != year) _last = null;
    Future.microtask(_load);
    return LeaveBalanceState(isLoading: true, balance: _last);
  }

  /// Lädt die Bilanz erneut (z. B. "Erneut versuchen" in der Fehleransicht).
  Future<void> reload() async {
    if (!ref.mounted) return;
    _gen++;
    state = LeaveBalanceState(isLoading: true, balance: _last);
    await _load();
  }

  /// Angemeldet wie die Repositories (`workRepositoryProvider`): über den
  /// Auth-Status, nicht über `FirebaseAuth.currentUser`.
  bool _isSignedIn() =>
      ref.read(core_providers.authStateProvider).asData?.value != null;

  Future<void> _load() async {
    final gen = _gen;
    bool stale() => !ref.mounted || gen != _gen;
    try {
      final year = ref.read(todayProvider).year;
      final settings = ref.read(core_providers.settingsRepositoryProvider);
      final LeaveBalance balance;
      if (_isSignedIn()) {
        final api = ref.read(core_providers.apiClientProvider);
        final profileId = ref.read(core_providers.activeWorkProfileIdProvider);
        final json = await api.getYearlyLeave(year, profileId: profileId);
        if (stale()) return;
        balance = _fromApi(json, year, settings.getVacationDaysPerYear());
      } else {
        final workRepository = ref.read(core_providers.workRepositoryProvider);
        final entitlement = settings.getVacationDaysPerYear();
        final perMonth = await Future.wait(
            List<Future<List<WorkEntryEntity>>>.generate(
                12, (i) => workRepository.getWorkEntriesForMonth(year, i + 1)));
        if (stale()) return;
        balance = calculateLeaveBalance(
            perMonth.expand((e) => e).toList(), year, entitlement);
      }
      _last = balance;
      state = LeaveBalanceState(balance: balance);
    } catch (e, st) {
      if (e is NotSignedInException) {
        // Kurz nach dem Abmelden oder Löschen des Kontos ist der Nutzer in
        // Firebase schon weg, Auth-Status und Repository zeigen aber noch auf
        // die API. Der Auth-Status zieht gleich nach und baut dieses ViewModel
        // neu (`ref.watch` der Repositories). Kein Fehlerzustand, sonst blitzt
        // in den Einstellungen kurz „Urlaubsdaten konnten nicht geladen
        // werden“ auf (#522).
        logger.i('[LeaveBalanceViewModel] Laden ohne angemeldeten Nutzer');
        return;
      }
      if (isExpectedLoadFailure(e)) {
        // Verbindungsabbruch ist kein App-Fehler (#506): nur info.
        logger.i('[LeaveBalanceViewModel] Netzwerkfehler beim Laden: '
            '${errorLabel(e)}');
      } else {
        logger.e('[LeaveBalanceViewModel] Fehler beim Laden: ${errorLabel(e)}',
            stackTrace: st);
      }
      if (stale()) return;
      state = const LeaveBalanceState(hasError: true);
    }
  }

  /// Bilanz aus der Antwort von `GET /api/reports/yearly/{year}`. Zusätzliche
  /// Felder werden ignoriert. [localEntitlement] gewinnt, wenn der Server
  /// einen anderen Anspruch meldet (Speichern noch unterwegs, siehe oben).
  LeaveBalance _fromApi(
      Map<String, dynamic> json, int year, int localEntitlement) {
    int? intOf(String key) => (json[key] as num?)?.toInt();
    final taken = intOf('vacationDaysTaken') ?? 0;
    final sick = intOf('sickDays') ?? 0;
    final serverEntitlement = intOf('vacationDaysPerYear');
    final serverRemaining = intOf('vacationDaysRemaining');
    final useServer =
        serverEntitlement == localEntitlement && serverRemaining != null;
    return LeaveBalance(
      year: year,
      entitlement: localEntitlement,
      taken: taken,
      remaining: useServer ? serverRemaining : localEntitlement - taken,
      sickDays: sick,
    );
  }
}
