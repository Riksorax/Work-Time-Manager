import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_work_time/core/utils/logger.dart';
import 'package:flutter_work_time/core/utils/api_errors.dart';

import '../../core/providers/providers.dart' as core_providers;
import '../../core/providers/today_provider.dart';
import '../../domain/entities/yearly_comparison.dart';
import '../../domain/utils/report_calculator.dart';
import '../../domain/utils/yearly_report_utils.dart';
import '../state/yearly_report_state.dart';

final yearlyReportViewModelProvider =
    NotifierProvider<YearlyReportViewModel, YearlyReportState>(
        YearlyReportViewModel.new);

/// Lädt den Jahresbericht (siehe #136).
///
/// - **Angemeldet (#530):** ein Aufruf
///   `GET /api/reports/yearly-comparison/{year}` **ohne** Stichtag (ganzes
///   Jahr); Summen und Monatswerte kommen aus `current`. Nicht an Premium
///   gebunden (das Gate liegt im Tab). Schlägt der Aufruf fehl (außer
///   `NotSignedInException`), rechnet die App lokal über die
///   Hybrid-Repositories als Ersatz (wie `ReportsViewModel` für Woche/Monat);
///   nur wenn auch das scheitert, zeigt der Tab einen Fehler mit „Erneut
///   versuchen“. Jahre, die das Backend nicht kennt (vor 2001, nach 2100),
///   werden lokal gerechnet.
/// - **Gast:** lokal aus 12 Monats-Abfragen über das Hybrid-Repository.
///
/// Die lokale Rechnung ist die kanonische Berichtsrechnung
/// (`calculateCanonicalMonthSummary` → `calculateMonthlyReport`), damit
/// Ersatz- und Backend-Werte übereinstimmen.
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

    if (_isSignedIn() && isComparisonYearSupported(year)) {
      try {
        final api = ref.read(core_providers.apiClientProvider);
        // Aktives Arbeitszeit-Profil mitgeben (siehe #239/#291).
        final profileId = ref.read(core_providers.activeWorkProfileIdProvider);
        final report =
            await api.getYearlyComparison(year, profileId: profileId);
        if (stale()) return;
        state = YearlyReportState.fromSummary(year, report.current);
        return;
      } catch (e, st) {
        if (e is NotSignedInException) {
          // Kurz nach dem Abmelden: der Auth-Status zieht gleich nach und baut
          // dieses ViewModel neu (#522). Kein Fehlerzustand, kein Ersatz.
          logger.i('[YearlyReportViewModel] Laden ohne angemeldeten Nutzer');
          return;
        }
        if (isExpectedLoadFailure(e)) {
          // Verbindungsabbruch ist kein App-Fehler (#506): nur info.
          logger.i('[YearlyReportViewModel] Jahreswerte nicht vom Backend '
              '($year), lokaler Ersatz: ${errorLabel(e)}');
        } else {
          logger.e(
              '[YearlyReportViewModel] Jahreswerte nicht vom Backend ($year), '
              'lokaler Ersatz: ${errorLabel(e)}',
              stackTrace: st);
        }
        if (stale()) return;
      }
      // Lokaler Ersatz; scheitert auch er, bleibt nur der Fehlerzustand.
      final months = await _loadLocal(year);
      if (stale()) return;
      state = months == null
          ? YearlyReportState(
              year: year,
              hasError: true,
              months: YearlyReportState.emptyMonths())
          : YearlyReportState(year: year, months: months);
      return;
    }

    final months = await _loadLocal(year);
    if (stale()) return;
    // Gast: wie bisher leere Werte statt Fehlerzustand.
    state = YearlyReportState(
        year: year, months: months ?? YearlyReportState.emptyMonths());
  }

  /// Lokale Jahresrechnung über die Hybrid-Repositories (kanonische
  /// Berichtsrechnung); `null`, wenn das Laden scheitert.
  Future<List<MonthSummary>?> _loadLocal(int year) async {
    final workRepository = ref.read(core_providers.workRepositoryProvider);
    final settingsRepository =
        ref.read(core_providers.settingsRepositoryProvider);
    final settings = ReportSettings(
      weeklyTargetHours: settingsRepository.getTargetWeeklyHours(),
      workdays: settingsRepository.getWorkdays(),
    );
    try {
      final entriesPerMonth = await Future.wait(
        List.generate(
            12, (i) => workRepository.getWorkEntriesForMonth(year, i + 1)),
      );
      return List.generate(
        12,
        (i) => calculateCanonicalMonthSummary(
          year: year,
          month: i + 1,
          entriesForMonth: entriesPerMonth[i],
          settings: settings,
        ),
      );
    } catch (e, stackTrace) {
      if (isExpectedLoadFailure(e)) {
        // Verbindungsabbruch ist kein App-Fehler (#506): nur info.
        logger.i('[YearlyReportViewModel] Netzwerkfehler beim Laden des '
            'Jahres $year: ${errorLabel(e)}');
      } else {
        logger.e(
            '[YearlyReportViewModel] Fehler beim Laden des Jahres $year: '
            '${errorLabel(e)}',
            stackTrace: stackTrace);
      }
      return null;
    }
  }
}
