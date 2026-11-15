import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_work_time/core/utils/api_errors.dart';
import 'package:flutter_work_time/core/utils/logger.dart';

import '../../core/providers/providers.dart' as core_providers;
import '../../core/providers/subscription_provider.dart';
import '../../core/providers/today_provider.dart';
import '../../domain/entities/yearly_comparison.dart';
import '../state/yearly_comparison_state.dart';
import 'yearly_report_view_model.dart';

final yearlyComparisonViewModelProvider =
    NotifierProvider<YearlyComparisonViewModel, YearlyComparisonState>(
  YearlyComparisonViewModel.new,
);

/// Jahresvergleich mit dem Vorjahr im Jahres-Tab (#530, Premium).
///
/// Die Rechnung liegt nur im Backend
/// (`GET /api/reports/yearly-comparison/{year}`); die App rechnet nichts und
/// hat keinen Offline-Fallback (Lade-, Fehler-, Leerzustand). Geladen wird
/// erst, wenn die Karte sichtbar ist ([ensureLoaded] aus dem Widget), und nur
/// angemeldet mit Premium; sonst bleibt der Zustand
/// [YearlyComparisonStatus.idle].
///
/// - Für das laufende Jahr geht der heutige lokale Kalendertag aus
///   [todayProvider] als Stichtag mit (`until=MM-dd`), für andere Jahre nicht.
/// - Jahres- (gewähltes Jahr des Jahres-Tabs), Login-, Premium- und
///   Profilwechsel bauen das ViewModel neu (Zustand `idle`, die sichtbare
///   Karte fordert sofort neu an); überholte Antworten verwirft der
///   Ladelauf-Zähler [_gen].
/// - Tageswechsel (`ref.listen(todayProvider)`, nie `watch`) lädt neu, wenn
///   schon geladen wurde (neuer Stichtag bzw. neues laufendes Jahr).
class YearlyComparisonViewModel extends Notifier<YearlyComparisonState> {
  /// Zählt Neuaufbau und Ladeläufe; ein überholter Lauf verwirft sein
  /// Ergebnis.
  int _gen = 0;

  @override
  YearlyComparisonState build() {
    _gen++;
    ref.watch(
      core_providers.authStateProvider.select((a) => a.asData?.value?.id),
    );
    ref.watch(isPremiumProvider);
    ref.watch(core_providers.activeWorkProfileIdProvider);
    final year = ref.watch(yearlyReportViewModelProvider.select((s) => s.year));
    ref.listen<DateTime>(todayProvider, (previous, next) {
      if (previous != null &&
          previous != next &&
          state.status != YearlyComparisonStatus.idle &&
          state.status != YearlyComparisonStatus.unsupported) {
        reload();
      }
    });
    return YearlyComparisonState(year: year);
  }

  bool _canLoad() =>
      ref.read(core_providers.authStateProvider).asData?.value != null &&
      ref.read(isPremiumProvider);

  /// Die Karte ist sichtbar: lädt, falls noch nichts angefordert ist.
  void ensureLoaded() {
    if (!ref.mounted || state.status != YearlyComparisonStatus.idle) return;
    _load();
  }

  /// „Erneut versuchen“ bzw. Neuladen nach einem Tageswechsel.
  Future<void> reload() => _load();

  Future<void> _load() async {
    if (!ref.mounted) return;
    final year = state.year;
    if (!_canLoad()) {
      _gen++;
      state = YearlyComparisonState(year: year);
      return;
    }
    if (!isComparisonYearSupported(year)) {
      _gen++;
      state = YearlyComparisonState(
        year: year,
        status: YearlyComparisonStatus.unsupported,
      );
      return;
    }
    final gen = ++_gen;
    bool stale() => !ref.mounted || gen != _gen;
    state = YearlyComparisonState(
      year: year,
      status: YearlyComparisonStatus.loading,
    );
    try {
      final api = ref.read(core_providers.apiClientProvider);
      final profileId = ref.read(core_providers.activeWorkProfileIdProvider);
      final today = ref.read(todayProvider);
      final report = await api.getYearlyComparison(
        year,
        until: year == today.year ? today : null,
        profileId: profileId,
      );
      if (stale()) return;
      state = YearlyComparisonState(
        year: year,
        status: YearlyComparisonStatus.data,
        report: report,
      );
    } catch (e, st) {
      if (e is NotSignedInException) {
        // Kurz nach dem Abmelden: der Auth-Status zieht gleich nach und baut
        // dieses ViewModel neu (#522). Kein Fehlerzustand.
        logger.i('[YearlyComparisonViewModel] Laden ohne angemeldeten Nutzer');
        return;
      }
      if (isExpectedLoadFailure(e)) {
        // Verbindungsabbruch ist kein App-Fehler (#506): nur info.
        logger.i(
          '[YearlyComparisonViewModel] Netzwerkfehler beim Laden: '
          '${errorLabel(e)}',
        );
      } else {
        logger.e(
          '[YearlyComparisonViewModel] Fehler beim Laden: ${errorLabel(e)}',
          stackTrace: st,
        );
      }
      if (stale()) return;
      state = YearlyComparisonState(
        year: year,
        status: YearlyComparisonStatus.error,
      );
    }
  }
}
