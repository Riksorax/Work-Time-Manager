import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_work_time/core/utils/api_errors.dart';
import 'package:flutter_work_time/core/utils/logger.dart';

import '../../core/providers/providers.dart' as core_providers;
import '../../core/providers/subscription_provider.dart';
import '../../core/providers/today_provider.dart';
import '../../domain/entities/trend_report.dart';
import '../state/trend_state.dart';

final trendViewModelProvider =
    NotifierProvider<TrendViewModel, TrendState>(TrendViewModel.new);

/// Trend der Berichte (#531, Premium): 12 Wochen oder 12 Monate bis heute.
///
/// Die Rechnung liegt nur im Backend (`GET /api/reports/trend/...`); die App
/// rechnet nichts und hat keinen Offline-Fallback (Lade-, Fehler-,
/// Leerzustand). Geladen wird erst, wenn die Ansicht sichtbar ist
/// ([ensureLoaded] aus dem Widget) und nur angemeldet mit Premium; sonst
/// bleibt der Zustand [TrendStatus.idle].
///
/// - Login-, Premium- und Profilwechsel bauen das ViewModel neu (Zustand
///   `idle`, die sichtbare Ansicht fordert sofort neu an); überholte Antworten
///   verwirft der Ladelauf-Zähler [_gen].
/// - Tageswechsel (`ref.listen(todayProvider)`, nie `watch`) lädt neu, wenn
///   schon geladen wurde.
/// - Die Wahl Wochen/Monate bleibt für die Laufzeit der App erhalten (auch
///   beim Tab-Wechsel und über Rebuilds), wird aber nicht gespeichert.
class TrendViewModel extends Notifier<TrendState> {
  TrendGranularity _granularity = TrendGranularity.week;

  /// Zählt Neuaufbau und Ladeläufe; ein überholter Lauf verwirft sein
  /// Ergebnis.
  int _gen = 0;

  @override
  TrendState build() {
    _gen++;
    ref.watch(
        core_providers.authStateProvider.select((a) => a.asData?.value?.id));
    ref.watch(isPremiumProvider);
    ref.watch(core_providers.activeWorkProfileIdProvider);
    ref.listen<DateTime>(todayProvider, (previous, next) {
      if (previous != null &&
          previous != next &&
          state.status != TrendStatus.idle) {
        reload();
      }
    });
    return TrendState(granularity: _granularity);
  }

  bool _canLoad() =>
      ref.read(core_providers.authStateProvider).asData?.value != null &&
      ref.read(isPremiumProvider);

  /// Die Ansicht ist sichtbar: lädt, falls noch nichts angefordert ist.
  void ensureLoaded() {
    if (!ref.mounted || state.status != TrendStatus.idle) return;
    _load();
  }

  /// „Erneut versuchen“ bzw. Neuladen nach einem Tageswechsel.
  Future<void> reload() => _load();

  /// Umschalten 12 Wochen / 12 Monate; lädt sofort neu.
  Future<void> setGranularity(TrendGranularity granularity) async {
    if (!ref.mounted || granularity == _granularity) return;
    _granularity = granularity;
    _gen++;
    state = TrendState(granularity: granularity);
    await _load();
  }

  Future<void> _load() async {
    if (!ref.mounted) return;
    if (!_canLoad()) {
      _gen++;
      state = TrendState(granularity: _granularity);
      return;
    }
    final gen = ++_gen;
    final granularity = _granularity;
    bool stale() => !ref.mounted || gen != _gen;
    state = TrendState(granularity: granularity, status: TrendStatus.loading);
    try {
      final api = ref.read(core_providers.apiClientProvider);
      final profileId = ref.read(core_providers.activeWorkProfileIdProvider);
      final today = ref.read(todayProvider);
      final report =
          await api.getTrendReport(today, granularity, profileId: profileId);
      if (stale()) return;
      state = TrendState(
          granularity: granularity, status: TrendStatus.data, report: report);
    } catch (e, st) {
      if (e is NotSignedInException) {
        // Kurz nach dem Abmelden: der Auth-Status zieht gleich nach und baut
        // dieses ViewModel neu (#522). Kein Fehlerzustand.
        logger.i('[TrendViewModel] Laden ohne angemeldeten Nutzer');
        return;
      }
      if (isExpectedLoadFailure(e)) {
        // Verbindungsabbruch ist kein App-Fehler (#506): nur info.
        logger
            .i('[TrendViewModel] Netzwerkfehler beim Laden: ${errorLabel(e)}');
      } else {
        logger.e('[TrendViewModel] Fehler beim Laden: ${errorLabel(e)}',
            stackTrace: st);
      }
      if (stale()) return;
      state = TrendState(granularity: granularity, status: TrendStatus.error);
    }
  }
}
