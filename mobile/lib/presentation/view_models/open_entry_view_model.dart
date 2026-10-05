import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_work_time/core/utils/logger.dart';

import '../../core/providers/clock_provider.dart';
import '../../core/providers/providers.dart';
import '../../core/providers/today_provider.dart';
import '../../domain/entities/work_entry_entity.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/usecases/close_open_work_entry.dart';
import '../../domain/utils/overtime_utils.dart';
import '../state/dashboard_state.dart';
import 'dashboard_view_model.dart';

/// Zustand des Banners für offene Einträge vor heute (#385).
class OpenEntryState extends Equatable {
  const OpenEntryState({
    this.entries = const [],
    this.busy = false,
    this.saveError = false,
    this.canResume = false,
  });

  /// Sichtbare Kandidaten, neuester zuerst.
  final List<WorkEntryEntity> entries;

  /// Eine Beenden-Aktion läuft (Doppeltippen wird ignoriert).
  final bool busy;

  /// Die letzte Beenden-Aktion ist fehlgeschlagen (UI zeigt eine Snackbar).
  final bool saveError;

  /// [current] darf im Dashboard fortgesetzt werden (`canResumeOpenEntry` mit
  /// aktuellem Dashboard-Zustand, #385 PR 1b).
  final bool canResume;

  WorkEntryEntity? get current => entries.isEmpty ? null : entries.first;

  /// Anzahl weiterer offener Einträge neben [current].
  int get moreCount => entries.isEmpty ? 0 : entries.length - 1;

  OpenEntryState copyWith({
    List<WorkEntryEntity>? entries,
    bool? busy,
    bool? saveError,
    bool? canResume,
  }) =>
      OpenEntryState(
        entries: entries ?? this.entries,
        busy: busy ?? this.busy,
        saveError: saveError ?? this.saveError,
        canResume: canResume ?? this.canResume,
      );

  @override
  List<Object?> get props => [entries, busy, saveError, canResume];
}

/// Schlüssel `<profileId>|<yyyy-MM-dd>` der Einträge, die der Nutzer in dieser
/// Sitzung mit "Später" ausgeblendet hat. Nicht persistent und unabhängig von
/// Repository/Profil, damit der Zustand einen Rebuild des ViewModels (Profil-,
/// Auth-, Tageswechsel) überlebt.
class OpenEntryDismissedNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void addAll(Iterable<String> keys) => state = {...state, ...keys};
}

final openEntryDismissedProvider =
    NotifierProvider<OpenEntryDismissedNotifier, Set<String>>(
        OpenEntryDismissedNotifier.new);

class OpenEntryViewModel extends Notifier<OpenEntryState> {
  /// Zählt Rebuilds (Profil-/Auth-Wechsel): eine Aktion des alten Stands darf
  /// nichts am neuen verändern.
  int _epoch = 0;

  /// Zählt Suchläufe: ein überholtes Ergebnis wird verworfen.
  int _loadGen = 0;

  /// Alle offenen Einträge vor heute aus der letzten Suche (ungefiltert).
  List<WorkEntryEntity> _candidates = const [];

  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _key(String profileId, DateTime date) {
    final d = _dayOf(date);
    return '$profileId|${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  /// Kalendertag des im Dashboard laufenden Eintrags, sonst `null`.
  static DateTime? _runningDay(WorkEntryEntity e) =>
      e.workStart != null && e.workEnd == null ? _dayOf(e.date) : null;

  /// Ist der heutige Tag im (fertig geladenen) Dashboard noch leer? Ein
  /// Urlaubs-/Krank-Eintrag von heute zählt nicht als leer.
  static bool _todayIsEmpty(DashboardState dashboard, DateTime now) {
    final e = dashboard.workEntry;
    return !dashboard.isLoading &&
        _dayOf(e.date) == _dayOf(now) &&
        e.type == WorkEntryType.work &&
        e.workStart == null;
  }

  String get _profileId => ref.read(activeWorkProfileIdProvider) ?? 'default';

  @override
  OpenEntryState build() {
    // Repo des aktiven Profils (Profil-/Auth-Wechsel baut neu).
    ref.watch(getOpenPastWorkEntriesUseCaseProvider);
    ref.watch(activeWorkProfileIdProvider);
    _epoch++;
    _candidates = const [];

    // Uhr beim Aufbau festhalten: `ref.read` im `select` ist nicht erlaubt.
    final clock = ref.read(clockProvider);

    // Immer listen, nie watch: sonst würde jeder Tageswechsel den Notifier neu
    // bauen (#387).
    ref.listen<DateTime>(todayProvider, (previous, next) {
      if (previous != next) unawaited(_load());
    });
    ref.listen<Set<String>>(openEntryDismissedProvider, (_, __) => _publish());
    // Record (laufender Tag, heute leer): "heute leer" ändert `canResume`.
    ref.listen<(DateTime?, bool)>(
      dashboardViewModelProvider
          .select((s) => (_runningDay(s.workEntry), _todayIsEmpty(s, clock()))),
      (previous, next) {
        // Das Dashboard hat den laufenden Eintrag beendet: er ist
        // abgeschlossen und darf nicht als offener Kandidat zurückkommen.
        final previousRunning = previous?.$1;
        if (previousRunning != null && next.$1 == null) {
          _candidates = _candidates
              .where((e) => _dayOf(e.date) != previousRunning)
              .toList();
        }
        _publish();
      },
    );

    Future.microtask(_load);
    return const OpenEntryState();
  }

  Future<void> _load() async {
    if (!ref.mounted) return;
    final epoch = _epoch;
    final gen = ++_loadGen;
    bool stale() => epoch != _epoch || gen != _loadGen || !ref.mounted;
    try {
      final found = await ref.read(getOpenPastWorkEntriesUseCaseProvider)();
      if (stale()) return;
      _candidates = found;
      _publish();
    } catch (e, st) {
      // Keine Eintragsinhalte loggen.
      logger.e('[OpenEntries] Suche fehlgeschlagen (${e.runtimeType})',
          stackTrace: st);
    }
  }

  /// Berechnet die sichtbaren Einträge aus den Kandidaten.
  void _publish() {
    if (!ref.mounted) return;
    final dismissed = ref.read(openEntryDismissedProvider);
    final running = _runningDay(ref.read(dashboardViewModelProvider).workEntry);
    final profileId = _profileId;
    final visible = _candidates
        .where((e) =>
            _dayOf(e.date) != running &&
            !dismissed.contains(_key(profileId, e.date)))
        .toList();
    final dashboard = ref.read(dashboardViewModelProvider);
    final now = ref.read(clockProvider)();
    final canResume = visible.isNotEmpty &&
        canResumeOpenEntry(
          entry: visible.first,
          now: now,
          todayIsEmpty: _todayIsEmpty(dashboard, now),
        );
    state = state.copyWith(entries: visible, canResume: canResume);
  }

  /// Tages-Soll am Datum von [entry] aus den Einstellungen des aktiven Profils.
  Duration targetFor(WorkEntryEntity entry) =>
      _targetFor(ref.read(settingsRepositoryProvider), entry);

  static Duration _targetFor(
          SettingsRepository settings, WorkEntryEntity entry) =>
      effectiveTargetForDate(
        date: entry.date,
        workdays: settings.getWorkdays(),
        weeklyHours: settings.getTargetWeeklyHours(),
      );

  /// "Später": blendet den Banner (alle Kandidaten des Profils) für diese
  /// Sitzung aus.
  void later() {
    final profileId = _profileId;
    ref
        .read(openEntryDismissedProvider.notifier)
        .addAll(_candidates.map((e) => _key(profileId, e.date)));
  }

  /// Setzt den aktuellen Eintrag im Dashboard fort (Pinning, #385 PR 1b). `true`
  /// = Dashboard läuft jetzt mit diesem Eintrag (der Listener blendet den Banner
  /// aus). Schreibt nichts, lädt nicht neu, fasst "Später" nicht an. Ein
  /// abgelehnter Versuch (`false`) bleibt still: der Banner wird neu
  /// veröffentlicht, Fehler loggt das Dashboard.
  Future<bool> resume() async {
    final entry = state.current;
    if (entry == null || state.busy) return false;
    state = state.copyWith(busy: true);

    // Zum Aktionsbeginn festhalten (Profilwechsel, #388).
    final epoch = _epoch;
    final dashboard = ref.read(dashboardViewModelProvider.notifier);
    final clock = ref.read(clockProvider);
    bool overtaken() => epoch != _epoch || !ref.mounted;

    var ok = false;
    try {
      // Zeit kann seit der Anzeige vergangen sein: Regel erneut prüfen.
      final now = clock();
      final allowed = canResumeOpenEntry(
        entry: entry,
        now: now,
        todayIsEmpty: _todayIsEmpty(ref.read(dashboardViewModelProvider), now),
      );
      if (allowed) ok = await dashboard.resumePastEntry(entry);
    } catch (e, st) {
      logger.e('[OpenEntries] Fortsetzen fehlgeschlagen (${e.runtimeType})',
          stackTrace: st);
    }
    if (overtaken()) return ok;

    state = state.copyWith(busy: false);
    _publish();
    return ok;
  }

  /// Beendet den aktuellen Eintrag mit [end]. Gibt `null` zurück, wenn nichts
  /// ausgeführt wurde (kein Eintrag oder Aktion läuft bereits).
  Future<CloseOpenEntryResult?> endEntry(DateTime end) async {
    final entry = state.current;
    if (entry == null || state.busy) return null;
    state = state.copyWith(busy: true, saveError: false);

    // Alles zum Aktionsbeginn festhalten (Profilwechsel mitten in der Aktion,
    // #388): kein `ref.read` nach einem `await`.
    final epoch = _epoch;
    final closeOpenWorkEntry = ref.read(closeOpenWorkEntryUseCaseProvider);
    final settings = ref.read(settingsRepositoryProvider);
    final dashboard = ref.read(dashboardViewModelProvider.notifier);
    bool overtaken() => epoch != _epoch || !ref.mounted;

    CloseOpenEntryResult result;
    try {
      final dailyTarget = _targetFor(settings, entry);
      result = await closeOpenWorkEntry(
          entry: entry, end: end, dailyTarget: dailyTarget);
    } catch (e, st) {
      logger.e('[OpenEntries] Beenden fehlgeschlagen (${e.runtimeType})',
          stackTrace: st);
      result = CloseOpenEntryResult.failed;
    }
    // Überholt: Writes sind im alten Profil gelandet, State/Reload gehören
    // nicht mehr zu dieser Aktion.
    if (overtaken()) return result;

    switch (result) {
      case CloseOpenEntryResult.closed:
      case CloseOpenEntryResult.alreadyClosed:
        _candidates = _candidates
            .where((e) => _dayOf(e.date) != _dayOf(entry.date))
            .toList();
        state = state.copyWith(busy: false);
        _publish();
        if (result == CloseOpenEntryResult.closed) {
          try {
            await dashboard.reloadAfterRetroClose();
          } catch (e, st) {
            logger.e(
                '[OpenEntries] Dashboard-Reload fehlgeschlagen '
                '(${e.runtimeType})',
                stackTrace: st);
          }
        }
        if (!overtaken()) await _load();
      case CloseOpenEntryResult.invalidEnd:
      case CloseOpenEntryResult.invalidEntry:
      case CloseOpenEntryResult.failed:
        state = state.copyWith(busy: false, saveError: true);
    }
    return result;
  }
}

final openEntryViewModelProvider =
    NotifierProvider<OpenEntryViewModel, OpenEntryState>(
        OpenEntryViewModel.new);
