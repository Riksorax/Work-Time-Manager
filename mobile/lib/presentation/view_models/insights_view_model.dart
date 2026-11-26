import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_work_time/core/utils/logger.dart';
import 'package:flutter_work_time/core/utils/api_errors.dart';
import 'package:flutter_work_time/core/utils/network_error.dart';

import '../../core/providers/providers.dart' as core_providers;
import '../../core/providers/today_provider.dart';
import '../state/insights_state.dart';
import '../state/reports_state.dart' show ReportsLoadFailure;

final insightsViewModelProvider =
    NotifierProvider<InsightsViewModel, InsightsState>(InsightsViewModel.new);

/// Arbeitszeit-Insights (siehe #134): Wochentags-Analyse, Burnout-Indikator
/// und Produktivitäts-Heatmap über drei Kalendermonate bis heute.
///
/// Die Werte kommen aus `analyticsRepositoryProvider` (#537): angemeldet vom
/// Backend (`GET /api/reports/insights/...`, kein Offline-Ersatz), als Gast aus
/// der lokalen Rechnung. Das ViewModel rechnet nichts.
///
/// - Geladen wird erst, wenn die Ansicht sichtbar ist ([ensureLoaded] aus dem
///   Widget) bzw. über [loadInsights]; "heute" nur beim Laden aus
///   [todayProvider], ohne Listener und ohne Auto-Reload (#387).
/// - Login- und Profilwechsel bauen das ViewModel neu (neues Repository); die
///   sichtbare Ansicht fordert dann neu an. Ein Ladelauf-Zähler verwirft späte
///   Antworten.
/// - Ladefehler setzen [InsightsState.loadFailure] (`offline`/`failed`);
///   `NotSignedInException` ergibt keinen Fehlerzustand (#522).
class InsightsViewModel extends Notifier<InsightsState> {
  int _gen = 0;
  bool _requested = false;

  @override
  InsightsState build() {
    _gen++;
    _requested = false;
    ref.watch(core_providers.analyticsRepositoryProvider);
    return InsightsState.initial();
  }

  /// Die Ansicht ist sichtbar: lädt, falls seit dem letzten Aufbau noch nichts
  /// angefordert wurde.
  void ensureLoaded() {
    if (!ref.mounted || _requested) return;
    loadInsights();
  }

  /// „Erneut versuchen“.
  Future<void> retry() => loadInsights();

  Future<void> loadInsights() async {
    if (!ref.mounted) return;
    _requested = true;
    final gen = ++_gen;
    bool stale() => !ref.mounted || gen != _gen;
    state =
        state.copyWith(isLoading: true, loadFailure: ReportsLoadFailure.none);

    final repository = ref.read(core_providers.analyticsRepositoryProvider);
    final today = ref.read(todayProvider);

    try {
      final report = await repository.insights(today);
      if (stale()) return;
      state = state.copyWith(
        isLoading: false,
        weekdayAverages: report.weekdayAverages,
        burnoutStatus: report.burnoutStatus,
        heatmap: report.heatmap,
        loadFailure: ReportsLoadFailure.none,
      );
    } catch (e, stackTrace) {
      if (e is NotSignedInException) {
        // Kurz nach dem Abmelden: der Auth-Status zieht gleich nach und baut
        // dieses ViewModel neu (#522). Kein Fehlerzustand.
        logger.i('[InsightsViewModel] Laden ohne angemeldeten Nutzer');
        return;
      }
      if (isExpectedLoadFailure(e)) {
        // Verbindungsabbruch ist kein App-Fehler (#506): nur info.
        logger.i('[InsightsViewModel] Netzwerkfehler beim Laden der Insights: '
            '${errorLabel(e)}');
      } else {
        logger.e(
            '[InsightsViewModel] Fehler beim Laden der Insights: '
            '${errorLabel(e)}',
            stackTrace: stackTrace);
      }
      if (stale()) return;
      state = state.copyWith(
        isLoading: false,
        weekdayAverages: const [],
        heatmap: const [],
        loadFailure: isTransientNetworkError(e)
            ? ReportsLoadFailure.offline
            : ReportsLoadFailure.failed,
      );
    }
  }
}
