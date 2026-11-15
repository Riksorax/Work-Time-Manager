import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_work_time/core/utils/logger.dart';
import 'package:flutter_work_time/core/utils/api_errors.dart';

import '../../core/providers/providers.dart' as core_providers;
import '../../core/providers/today_provider.dart';
import '../../domain/entities/yearly_comparison.dart';
import '../../domain/utils/yearly_report_utils.dart';
import '../state/yearly_report_state.dart';

final yearlyReportViewModelProvider =
    NotifierProvider<YearlyReportViewModel, YearlyReportState>(
        YearlyReportViewModel.new);

/// Lädt den Jahresbericht (siehe #136).
///
/// - **Angemeldet (#530):** ein Aufruf
///   `GET /api/reports/yearly-comparison/{year}` **ohne** Stichtag (ganzes
///   Jahr); Summen und Monatswerte kommen aus `current`. Die App rechnet
///   nichts nach und hat keinen lokalen Ersatz: schlägt der Aufruf fehl, zeigt
///   der Tab einen Fehler mit „Erneut versuchen“. Jahre, die das Backend nicht
///   kennt (vor 2001, nach 2100), werden nicht angefragt und gelten als leer.
///   Nicht an Premium gebunden (das Gate liegt im Tab).
/// - **Gast:** lokal aus 12 Monats-Abfragen über das Hybrid-Repository
///   (`calculateMonthSummary`).
///
/// Login- und Profilwechsel bauen das ViewModel über `workRepositoryProvider`
/// neu; war schon ein Jahr geladen, wird dasselbe Jahr neu geladen (sonst
/// bliebe der sichtbare Tab im Ladezustand stehen). Der Ladelauf-Zähler
/// [_gen] verwirft überholte Antworten (Jahres-, Profil-, Login-Wechsel).
class YearlyReportViewModel extends Notifier<YearlyReportState> {
  /// Zuletzt angefordertes Jahr; überlebt den Neuaufbau des Notifiers.
  int? _requestedYear;

  int _gen = 0;

  @override
  YearlyReportState build() {
    _gen++;
    ref.watch(core_providers.workRepositoryProvider);
    // Nur Startjahr aus todayProvider (read, kein watch/listen): das gewählte
    // Jahr bleibt über den Jahreswechsel bestehen, kein Auto-Reload (#387).
    final requested = _requestedYear;
    if (requested != null) {
      Future.microtask(() {
        if (ref.mounted && _requestedYear == requested) loadYear(requested);
      });
      return YearlyReportState.initial(requested);
    }
    return YearlyReportState.initial(ref.read(todayProvider).year);
  }

  /// Angemeldet wie die Repositories (`workRepositoryProvider`): über den
  /// Auth-Status, nicht über `FirebaseAuth.currentUser`.
  bool _isSignedIn() =>
      ref.read(core_providers.authStateProvider).asData?.value != null;

  Future<void> loadYear(int year) async {
    if (!ref.mounted) return;
    _requestedYear = year;
    final gen = ++_gen;
    bool stale() => !ref.mounted || gen != _gen;
    state = YearlyReportState.initial(year);

    if (_isSignedIn()) {
      await _loadFromApi(year, stale);
    } else {
      await _loadLocal(year, stale);
    }
  }

  Future<void> _loadFromApi(int year, bool Function() stale) async {
    if (!isComparisonYearSupported(year)) {
      state = YearlyReportState(
          year: year, months: YearlyReportState.emptyMonths());
      return;
    }
    try {
      final api = ref.read(core_providers.apiClientProvider);
      // Aktives Arbeitszeit-Profil mitgeben (siehe #239/#291).
      final profileId = ref.read(core_providers.activeWorkProfileIdProvider);
      final report = await api.getYearlyComparison(year, profileId: profileId);
      if (stale()) return;
      state = YearlyReportState.fromSummary(year, report.current);
    } catch (e, st) {
      if (e is NotSignedInException) {
        // Kurz nach dem Abmelden: der Auth-Status zieht gleich nach und baut
        // dieses ViewModel neu (#522). Kein Fehlerzustand.
        logger.i('[YearlyReportViewModel] Laden ohne angemeldeten Nutzer');
        return;
      }
      if (isExpectedLoadFailure(e)) {
        // Verbindungsabbruch ist kein App-Fehler (#506): nur info.
        logger.i('[YearlyReportViewModel] Netzwerkfehler beim Laden des '
            'Jahres $year: ${errorLabel(e)}');
      } else {
        logger.e(
            '[YearlyReportViewModel] Fehler beim Laden des Jahres $year: '
            '${errorLabel(e)}',
            stackTrace: st);
      }
      if (stale()) return;
      state = YearlyReportState(
          year: year, hasError: true, months: YearlyReportState.emptyMonths());
    }
  }

  Future<void> _loadLocal(int year, bool Function() stale) async {
    final workRepository = ref.read(core_providers.workRepositoryProvider);
    final settingsRepository =
        ref.read(core_providers.settingsRepositoryProvider);
    final workdays = settingsRepository.getWorkdays();
    final targetWeeklyHours = settingsRepository.getTargetWeeklyHours();

    List<MonthSummary> months;
    try {
      final entriesPerMonth = await Future.wait(
        List.generate(
            12, (i) => workRepository.getWorkEntriesForMonth(year, i + 1)),
      );
      months = List.generate(12, (i) {
        return calculateMonthSummary(
          month: i + 1,
          entriesForMonth: entriesPerMonth[i],
          workdays: workdays,
          targetWeeklyHours: targetWeeklyHours,
        );
      });
    } catch (e, stackTrace) {
      if (isExpectedLoadFailure(e)) {
        // Verbindungsabbruch ist kein App-Fehler (#506): nur info.
        logger.i(
            '[YearlyReportViewModel] Netzwerkfehler beim Laden des Jahres $year: $e');
      } else {
        logger.e(
            '[YearlyReportViewModel] Fehler beim Laden des Jahres $year: $e',
            stackTrace: stackTrace);
      }
      months = YearlyReportState.emptyMonths();
    }
    if (stale()) return;
    state = YearlyReportState(year: year, months: months);
  }
}
