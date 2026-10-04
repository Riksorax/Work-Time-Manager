import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_work_time/core/utils/logger.dart';
import 'package:flutter_work_time/core/utils/time_precision.dart';

import '../../core/providers/clock_provider.dart';
import '../../core/providers/providers.dart';
import '../../core/providers/today_provider.dart';
import '../../domain/entities/break_entity.dart';
import '../../domain/entities/work_entry_entity.dart';
import '../../domain/services/break_calculator_service.dart';
import '../../domain/utils/overtime_utils.dart';
import '../../domain/utils/overtime_warning_utils.dart';
import '../../l10n/app_localizations.dart';
import '../state/dashboard_state.dart';

class DashboardViewModel extends Notifier<DashboardState> {
  Timer? _timer;
  Timer? _autoSaveTimer;
  int _tickCounter = 0;

  /// Generationszähler: jeder `_init` erhöht ihn; ein überholter Lauf (oder
  /// einer nach Dispose) verwirft sein Ergebnis (#379).
  int _initGen = 0;

  /// Der zuletzt gestartete Ladelauf (Aktionen warten darauf, siehe
  /// [_ensureCurrentDay]).
  Future<void>? _initRun;

  /// Ob der letzte `_init` erfolgreich war. Ohne erfolgreichen Ladevorgang ist
  /// `state.workEntry` nur ein Platzhalter und darf nie gespeichert werden.
  bool _loadedOk = false;

  /// Die aktuelle Zeit aus [clockProvider] (Tests injizieren eine Fake-Uhr).
  DateTime _now() => ref.read(clockProvider)();

  static bool _isRunning(WorkEntryEntity e) =>
      e.workStart != null && e.workEnd == null;

  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  DashboardState build() {
    // Watch dependencies to trigger rebuild on updates (e.g. Auth change)
    ref.watch(getTodayWorkEntryUseCaseProvider);
    ref.watch(getOvertimeUseCaseProvider);
    ref.watch(settingsRepositoryProvider);

    _loadedOk = false;
    ref.listen<DateTime>(todayProvider, (previous, next) {
      if (previous != next) _onDayChange();
    });
    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
      _autoSaveTimer?.cancel();
      _autoSaveTimer = null;
      _initGen++;
    });

    // Start initial load
    Future.microtask(() => _init());
    return DashboardState.initial(now: _now());
  }

  /// Tageswechsel: ein laufender Eintrag bleibt unverändert am Starttag, ein
  /// gestoppter oder leerer Eintrag schaltet still auf den neuen Tag.
  void _onDayChange() {
    if (!ref.mounted) return;
    if (_isRunning(state.workEntry)) return;
    unawaited(_init(dayChange: true));
  }

  Future<void> _init({bool dayChange = false}) {
    if (!ref.mounted) return Future.value();
    final gen = ++_initGen;
    final run = _load(gen, dayChange);
    _initRun = run;
    return run;
  }

  Future<void> _load(int gen, bool dayChange) async {
    bool stale() => gen != _initGen || !ref.mounted;
    try {
      logger.i('[Dashboard] Initialisiere Dashboard...');
      final getTodayWorkEntry = ref.read(getTodayWorkEntryUseCaseProvider);
      final overtimeRepository = ref.read(overtimeRepositoryProvider);

      final workEntry = await getTodayWorkEntry.call();
      if (stale()) return;
      // Async laden statt synchronem Cache-Zugriff (verhindert Race Condition bei Firebase-Login)
      final storedOvertime = await overtimeRepository.ensureOvertimeLoaded();
      if (stale()) return;
      final lastUpdateDate = await overtimeRepository.ensureLastUpdateLoaded();
      if (stale()) return;

      // Berechne dailyOvertime für den initialen Stand
      final targetDailyHours = _getEffectiveTargetDailyHours(workEntry.date);
      final isExtraDay = targetDailyHours == Duration.zero;
      Duration initialDailyOvertime = Duration.zero;

      if (workEntry.workStart != null && workEntry.workEnd != null) {
        // Wenn der Tag bereits abgeschlossen ist, berechne Overtime basierend auf dem Eintrag
        final breakDuration = workEntry.breaks.fold<Duration>(
          Duration.zero,
          (previousValue, element) =>
              previousValue +
              (element.end?.difference(element.start) ?? Duration.zero),
        );
        final actualWorkDuration =
            workEntry.workEnd!.difference(workEntry.workStart!) - breakDuration;
        initialDailyOvertime = actualWorkDuration - targetDailyHours;
      } else if (workEntry.workStart != null) {
        // Laufender Tag -> Overtime wird im Timer berechnet.
        // Um initialOvertime (Basis) korrekt wiederherzustellen, müssen wir den aktuellen "Tagesfortschritt" vom gespeicherten Gesamtwert abziehen.
        final now = _now();

        // Berechne aktuelle Pausenzeit
        final breakDuration = _calculateTotalBreakDuration(now, workEntry);

        // Berechne aktuelle Arbeitszeit (Brutto - Pause)
        final elapsedTime =
            now.difference(workEntry.workStart!) - breakDuration;

        // Aktueller Überstunden-Stand für heute (wird meist negativ sein, da Tag noch läuft)
        initialDailyOvertime = elapsedTime - targetDailyHours;
      }

      Duration initialOvertime;
      if (dayChange) {
        // Tageswechsel: storedOvertime ist die Basis (Stand bis gestern).
        // Ausnahme: der neue Eintrag ist schon abgeschlossen und sein Anteil
        // wurde nach seinem Ende gespeichert.
        final dailyAlreadyStored = workEntry.workStart != null &&
            workEntry.workEnd != null &&
            lastUpdateDate != null &&
            !lastUpdateDate.isBefore(workEntry.workEnd!);
        initialOvertime = dailyAlreadyStored
            ? storedOvertime - initialDailyOvertime
            : storedOvertime;
      } else if (lastUpdateDate != null &&
          DateUtils.isSameDay(lastUpdateDate, _now())) {
        // Wenn das Update heute war, beinhaltet storedOvertime bereits den heutigen Tag.
        // Wir müssen den heutigen Anteil abziehen, um die Basis (Start des Tages) zu bekommen.
        // Aber ACHTUNG: Das gespeicherte Daily könnte anders sein als das jetzt berechnete (z.B. nach Edit).
        // Wir nehmen an: Base = Stored - "Daily at save time".
        // Das ist schwierig.
        // Strategie: Wir vertrauen storedOvertime als "Total".
        // Aber wir wollen Base + Daily anzeigen.
        // Wenn wir storedOvertime als Total nehmen, ist Base = Total - Daily.
        initialOvertime = storedOvertime - initialDailyOvertime;
      } else {
        // Neuer Tag oder noch nie heute gespeichert: Stored ist Base (von gestern).
        initialOvertime = storedOvertime;
      }

      final totalOvertime = initialOvertime + initialDailyOvertime;

      logger.i(
          '[Dashboard] Geladener WorkEntry - Start: ${workEntry.workStart}, End: ${workEntry.workEnd}');
      logger.i(
          '[Dashboard] Overtime Init: Stored=$storedOvertime, InitialBase=$initialOvertime, Daily=$initialDailyOvertime, Total=$totalOvertime, ExtraDay=$isExtraDay');

      // Neu per Konstruktor statt copyWith: copyWith ignoriert null und
      // würde Werte des Vortags (Dauer, erwartetes Ende) stehen lassen.
      state = DashboardState(
        workEntry: workEntry,
        elapsedTime: Duration.zero,
        isLoading: false,
        totalOvertime: totalOvertime,
        initialOvertime: initialOvertime,
        dailyOvertime: initialDailyOvertime,
        isExtraDay: isExtraDay,
      );
      _loadedOk = true;
      await _recalculateStateAndSave(workEntry, save: false);
      if (stale()) return;
      _startTimerIfNeeded();
    } catch (e, st) {
      // Nur der aktuelle Lauf darf den Zustand ändern. Keine Nutzerdaten loggen.
      logger.e('[Dashboard] Laden fehlgeschlagen (${e.runtimeType})',
          stackTrace: st);
      if (!stale()) {
        _loadedOk = false;
        state = state.copyWith(isLoading: false);
      }
    }
  }

  /// Stellt vor einer Schreibaktion sicher, dass das Dashboard den aktuellen
  /// Tag zeigt. Ein laufender Eintrag bleibt am Starttag. Gibt `false`
  /// zurück, wenn der aktuelle Tag nicht geladen werden konnte: die Aktion
  /// muss dann abbrechen (nie in den Vortag oder einen Platzhalter schreiben).
  Future<bool> _ensureCurrentDay() async {
    if (!ref.mounted) return false;
    if (_isRunning(state.workEntry)) return true;

    ref.read(todayProvider.notifier).refresh();
    final pending = _initRun;
    if (pending != null) await pending;
    if (!ref.mounted) return false;

    final today = ref.read(todayProvider);
    bool current() =>
        _loadedOk &&
        (_isRunning(state.workEntry) || _dayOf(state.workEntry.date) == today);
    if (!current()) {
      // Tageswechsel-Basis nur, wenn wirklich ein Vortag angezeigt wird; beim
      // Retry eines fehlgeschlagenen Erstladens (Platzhalter = heute) gilt die
      // normale Heuristik (sonst wäre die Basis bei einem heute schon
      // gespeicherten Saldo falsch).
      await _init(dayChange: _dayOf(state.workEntry.date) != today);
      if (!ref.mounted) return false;
      if (!current()) return false;
    }
    return true;
  }

  /// Berechnet das effektive Tages-Soll für [forDate] (Datum des Eintrags,
  /// nicht "heute": ein über Mitternacht laufender Eintrag behält das Soll
  /// seines Starttags, siehe #379).
  Duration _getEffectiveTargetDailyHours(DateTime forDate) {
    final settingsRepository = ref.read(settingsRepositoryProvider);
    final workdays = settingsRepository.getWorkdays();
    if (workdays.isEmpty) return Duration.zero;
    final regularDailyTarget = roundDurationToMinute(Duration(
      microseconds: (settingsRepository.getTargetWeeklyHours() /
              workdays.length *
              Duration.microsecondsPerHour)
          .round(),
    ));
    return getEffectiveDailyTarget(
      date: forDate,
      workdays: workdays,
      regularDailyTarget: regularDailyTarget,
    );
  }

  void updateOvertimeFromSettings(Duration newBase) {
    // Der User gibt die Basis-Bilanz aus Vortagen ein (nicht inkl. heute).
    // Total = Basis + Heutige Überstunden.
    final currentDaily = state.dailyOvertime ?? Duration.zero;
    state = state.copyWith(
      initialOvertime: newBase,
      totalOvertime: newBase + currentDaily,
    );
  }

  /// Berechnet die Überstunden neu, wenn sich die Einstellungen (Sollstunden/Arbeitstage) ändern
  void recalculateOvertimeFromSettings() {
    logger.i('[Dashboard] Neuberechnung nach Einstellungsänderung');

    if (state.workEntry.workStart == null) {
      return;
    }
    _recalculateOvertime();
  }

  void _startTimerIfNeeded() {
    _timer?.cancel();
    _autoSaveTimer?.cancel();

    if (state.workEntry.workStart != null && state.workEntry.workEnd == null) {
      logger.i('[Dashboard] Starte Timer...');
      _tickCounter = 0;

      // Sofortiges Update
      final now = _now();
      final initialElapsedTime = _calculateElapsedTime();
      final initialGrossDuration = now.difference(state.workEntry.workStart!);

      state = state.copyWith(
        elapsedTime: initialElapsedTime,
        grossWorkDuration: initialGrossDuration,
      );
      _recalculateOvertime();

      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!ref.mounted) return;
        // Standby-Härtung: ein verpasster Mitternachts-Timer wird hier
        // nachgeholt (der laufende Eintrag bleibt am Starttag).
        ref.read(todayProvider.notifier).refresh();
        if (!ref.mounted) return;
        final now = _now();
        final elapsedTime = _calculateElapsedTime();
        final grossDuration = state.workEntry.workStart != null
            ? now.difference(state.workEntry.workStart!)
            : Duration.zero;

        state = state.copyWith(
          elapsedTime: elapsedTime,
          grossWorkDuration: grossDuration,
        );
        _recalculateOvertime();

        // Auto-Save alle 30 Sekunden
        _tickCounter++;
        if (_tickCounter >= 30) {
          _tickCounter = 0;
          unawaited(_autoSave());
        }
      });
    } else {
      logger.i(
          '[Dashboard] Timer nicht gestartet (Start: ${state.workEntry.workStart}, End: ${state.workEntry.workEnd})');
    }
  }

  Future<void> _autoSave() async {
    // Kein Generations-/id-Guard: der Timer läuft nur bei laufendem Eintrag,
    // wird in `_startTimerIfNeeded` und `onDispose` abgebrochen, und ein
    // Reinit (Rebuild, Tageswechsel, Stop) findet nie bei laufendem Timer statt
    // (`_onDayChange`/`_ensureCurrentDay` lassen laufende Einträge unberührt).
    // Ein Guard wäre unerreichbar (Rot-Nachweis nicht möglich, #379).
    // Nur speichern, wenn tatsächlich eine Zeiterfassung läuft
    if (state.workEntry.workStart == null) {
      logger.i('[Dashboard] Auto-Save übersprungen: Keine Zeiterfassung aktiv');
      return;
    }

    logger.i('[Dashboard] Auto-Save: Speichere aktuellen Stand');
    try {
      final saveWorkEntry = ref.read(saveWorkEntryUseCaseProvider);
      await saveWorkEntry.call(state.workEntry);
      logger.i('[Dashboard] Auto-Save erfolgreich');
    } catch (e) {
      logger.e('[Dashboard] Auto-Save Fehler: $e');
    }
  }

  /// Ende der Berechnung: `workEnd` bei beendetem Eintrag, sonst "jetzt".
  /// Ein beendeter Eintrag darf nie mit der Uhr gerechnet werden (#386).
  DateTime _calculationEnd() => state.workEntry.workEnd ?? _now();

  Duration _calculateElapsedTime() {
    if (state.workEntry.workStart == null) return Duration.zero;
    final end = _calculationEnd();
    final breakDuration = _calculateTotalBreakDuration(end);
    return end.difference(state.workEntry.workStart!) - breakDuration;
  }

  void _recalculateOvertime() {
    if (state.workEntry.workStart == null) return;

    final targetDailyHours =
        _getEffectiveTargetDailyHours(state.workEntry.date);
    final dailyOvertime = _calculateElapsedTime() - targetDailyHours;

    // Berechne Total = Base (initialOvertime) + Daily
    final base = state.initialOvertime ?? Duration.zero;
    final total = base + dailyOvertime;

    // Berechne voraussichtliche Feierabendzeit für ±0 (Tagesziel)
    final expectedEndTime = _calculateExpectedEndTime(targetDailyHours);

    // Berechne voraussichtliche Feierabendzeit für Gesamtbilanz ±0
    // Wenn wir z.B. 1h Plus haben, müssen wir heute 1h weniger arbeiten.
    // Wenn wir 10h Plus haben und 8h Soll, müssen wir gar nicht arbeiten (Ende = Start).
    final Duration remainingForTotalZero = targetDailyHours - base;
    final Duration targetForTotalZero = remainingForTotalZero.isNegative
        ? Duration.zero
        : remainingForTotalZero;
    final expectedEndTotalZero = _calculateExpectedEndTime(targetForTotalZero);

    state = state.copyWith(
      dailyOvertime: dailyOvertime,
      totalOvertime: total,
      expectedEndTime: expectedEndTime,
      expectedEndTotalZero: expectedEndTotalZero,
      isExtraDay: targetDailyHours == Duration.zero,
    );
  }

  /// Berechnet die voraussichtliche Feierabendzeit für ±0 heutige Überstunden
  DateTime? _calculateExpectedEndTime(Duration targetDailyHours) {
    if (state.workEntry.workStart == null) return null;

    final start = state.workEntry.workStart!;
    final end = _calculationEnd();

    // Bereits genommene Pausen (bis jetzt bzw. bis zum Ende)
    var currentBreaks = _calculateTotalBreakDuration(end);

    // Iterative Berechnung, da zusätzliche Pausen die Brutto-Zeit erhöhen
    // und dadurch ggf. weitere Pausenregeln greifen (z.B. Sprung über 9h).
    var projectedEnd = start.add(targetDailyHours).add(currentBreaks);

    for (int i = 0; i < 2; i++) {
      // Max 2 Iterationen reichen für 6h/9h Regeln
      final grossDuration = projectedEnd.difference(start);
      Duration requiredBreaks = Duration.zero;

      if (grossDuration >= BreakCalculatorService.minWorkTimeForSecondBreak) {
        requiredBreaks =
            BreakCalculatorService.requiredBreakTimeForLongDay; // 45 min
      } else if (grossDuration >=
          BreakCalculatorService.minWorkTimeForFirstBreak) {
        requiredBreaks = BreakCalculatorService.firstBreakDuration; // 30 min
      }

      final missingBreak = requiredBreaks - currentBreaks;
      if (missingBreak > Duration.zero) {
        // Wir müssen die Pause verlängern/ergänzen
        currentBreaks += missingBreak;
        projectedEnd = start.add(targetDailyHours).add(currentBreaks);
      } else {
        // Keine zusätzlichen Pausen nötig
        break;
      }
    }

    return projectedEnd;
  }

  Duration _calculateTotalBreakDuration(DateTime now,
      [WorkEntryEntity? entry]) {
    final e = entry ?? state.workEntry;
    if (e.workEnd != null) {
      // Beendeter Eintrag: nur abgeschlossene Pausen, offene zaehlt 0
      // (wie _load und _recalculateStateAndSave).
      return e.breaks.fold(Duration.zero,
          (prev, b) => prev + (b.end?.difference(b.start) ?? Duration.zero));
    }
    return e.breaks.fold(Duration.zero, (prev, b) {
      if (b.start.isAfter(now)) return prev;
      final end = b.end ?? now;
      return prev + end.difference(b.start);
    });
  }

  Future<void> startOrStopTimer() async {
    if (!await _ensureCurrentDay()) return;
    final now = roundToMinute(_now());
    WorkEntryEntity updatedEntry;

    if (state.workEntry.workStart == null) {
      // START - Erster Start des Tages
      updatedEntry = state.workEntry.copyWith(workStart: now);
      logger.i('[Dashboard] Timer gestartet um $now');
    } else if (state.workEntry.workEnd == null) {
      // STOP - Arbeit beenden
      _timer?.cancel();
      updatedEntry = state.workEntry.copyWith(workEnd: now);
      logger.i('[Dashboard] Timer gestoppt um $now');

      // Berechne automatische Pausen beim Beenden (nur wenn keine Pause läuft und Typ Arbeit ist)
      final hasRunningBreak = updatedEntry.breaks.any((b) => b.end == null);
      if (!hasRunningBreak && updatedEntry.type == WorkEntryType.work) {
        logger.i('[Dashboard] Berechne automatische Pausen...');
        updatedEntry =
            BreakCalculatorService.calculateAndApplyBreaks(updatedEntry);
        logger.i(
            '[Dashboard] Automatische Pausen berechnet: ${updatedEntry.breaks.length} Pausen');
      } else {
        logger.i(
            '[Dashboard] Automatische Pausen übersprungen: Pause läuft noch oder Sonder-Eintrag');
      }
    } else {
      // Arbeit wurde bereits beendet - Benutzer muss entscheiden
      // Diese Methode wird vom UI mit dem gewählten Modus aufgerufen
      logger.i(
          '[Dashboard] Arbeit bereits beendet - Benutzer muss Aktion wählen');
      return; // UI zeigt Dialog an
    }

    await _recalculateStateAndSave(updatedEntry);
  }

  /// Startet eine komplett neue Session (Start, End und Pausen zurücksetzen)
  Future<void> startNewSession() async {
    if (!await _ensureCurrentDay()) return;
    final now = roundToMinute(_now());
    final updatedEntry = WorkEntryEntity(
      id: state.workEntry.id,
      date: state.workEntry.date,
      workStart: now,
      workEnd: null,
      breaks: const [], // Pausen zurücksetzen
      manualOvertime: state.workEntry.manualOvertime,
      isManuallyEntered: false,
      description: state.workEntry.description,
      type: state.workEntry.type,
    );
    logger.i(
        '[Dashboard] Komplett neue Session gestartet um $now (Start, End, Pausen zurückgesetzt)');
    await _recalculateStateAndSave(updatedEntry);
  }

  /// Neue Session mit Pausen behalten (nur Start und Endzeit zurücksetzen)
  Future<void> startNewSessionKeepBreaks() async {
    if (!await _ensureCurrentDay()) return;
    final now = roundToMinute(_now());
    final updatedEntry = WorkEntryEntity(
      id: state.workEntry.id,
      date: state.workEntry.date,
      workStart: now,
      workEnd: null, // Endzeit entfernen
      breaks: state.workEntry.breaks, // Pausen behalten
      manualOvertime: state.workEntry.manualOvertime,
      isManuallyEntered: false,
      description: state.workEntry.description,
      type: state.workEntry.type,
    );
    logger.i('[Dashboard] Neue Session gestartet um $now (Pausen behalten)');
    await _recalculateStateAndSave(updatedEntry);
  }

  Future<void> _recalculateStateAndSave(WorkEntryEntity updatedEntry,
      {bool save = true}) async {
    Duration? newActualWorkDuration;
    Duration? newTotalOvertime = state.totalOvertime;
    Duration? dailyOvertime;
    bool? isExtraDay;
    var saved = false;

    Duration? newGrossWorkDuration;
    if (updatedEntry.workStart != null && updatedEntry.workEnd != null) {
      newGrossWorkDuration =
          updatedEntry.workEnd!.difference(updatedEntry.workStart!);

      final breakDuration = updatedEntry.breaks.fold<Duration>(
        Duration.zero,
        (previousValue, element) =>
            previousValue +
            (element.end?.difference(element.start) ?? Duration.zero),
      );
      newActualWorkDuration =
          updatedEntry.workEnd!.difference(updatedEntry.workStart!) -
              breakDuration;

      final targetDailyHours = _getEffectiveTargetDailyHours(updatedEntry.date);
      isExtraDay = targetDailyHours == Duration.zero;
      dailyOvertime = newActualWorkDuration - targetDailyHours;

      // Total = Base + Daily
      final base = state.initialOvertime ?? Duration.zero;
      newTotalOvertime = base + dailyOvertime;

      if (save) {
        logger.i(
            '[Dashboard] Speichere Overtime: Base=$base, Daily=$dailyOvertime, NewTotal=$newTotalOvertime');

        final overtimeRepository = ref.read(overtimeRepositoryProvider);
        await overtimeRepository.saveOvertime(newTotalOvertime);
        await overtimeRepository.saveLastUpdateDate(_now());
        await _checkOvertimeWarning(newTotalOvertime);
        if (!ref.mounted) return;
      }
    } else {
      newActualWorkDuration = null;
      // Wenn der Timer läuft, wird grossWorkDuration vom Timer aktualisiert.
      // Wir setzen es hier auf null, damit der Timer (oder die UI Logik) übernimmt.
      // Außer wir wollen einen initialen Wert für den Start setzen?
      // Der Timer startet sofort in _startTimerIfNeeded und setzt den Wert.
      newGrossWorkDuration = null;

      // dailyOvertime bleibt null oder wird neu berechnet wenn Timer läuft,
      // aber hier (bei Start/Stop) ist es nur relevant wenn gestoppt.
      // Wenn gestartet: dailyOvertime wird im Timer Loop berechnet.
    }

    state = state.copyWith(
      workEntry: updatedEntry,
      actualWorkDuration: newActualWorkDuration,
      grossWorkDuration: newGrossWorkDuration,
      totalOvertime: newTotalOvertime,
      dailyOvertime: dailyOvertime,
      isExtraDay: isExtraDay,
    );

    if (save) {
      logger.i(
          '[Dashboard] Speichere WorkEntry: ${updatedEntry.id}, Start: ${updatedEntry.workStart}, End: ${updatedEntry.workEnd}');
      final saveWorkEntry = ref.read(saveWorkEntryUseCaseProvider);
      try {
        await saveWorkEntry.call(updatedEntry);
        saved = true;
        logger.i('[Dashboard] WorkEntry erfolgreich gespeichert');
      } catch (e, st) {
        // Transiente Fehler (z. B. Netzwerkabbruch beim Abruf des ID-Tokens)
        // dürfen den Timer nicht abstürzen lassen (#336). Der State ist bereits
        // aktualisiert, der Timer läuft weiter; der nächste Speichervorgang
        // schreibt den vollständigen Eintrag erneut.
        logger.e('[Dashboard] WorkEntry konnte nicht gespeichert werden: $e',
            stackTrace: st);
      }
    }
    if (!ref.mounted) return;
    _startTimerIfNeeded();

    // Stop (bzw. Bearbeitung) eines über Mitternacht gelaufenen Vortags:
    // danach auf den aktuellen Tag umschalten (der Eintrag selbst bleibt am
    // Starttag gespeichert).
    if (saved &&
        updatedEntry.workEnd != null &&
        _dayOf(updatedEntry.date) != _dayOf(_now())) {
      // refresh() zieht todayProvider nach (Standby) und startet über den
      // Listener bereits den Reinit; sonst starten wir ihn selbst.
      final gen = _initGen;
      ref.read(todayProvider.notifier).refresh();
      if (gen == _initGen) {
        await _init(dayChange: true);
      } else {
        await _initRun;
      }
    }
  }

  /// Prüft nach jedem Speichern des Gleitzeitsaldos, ob ein konfigurierter
  /// Über-/Minusstunden-Schwellwert erreicht ist, und löst ggf. eine
  /// Benachrichtigung aus (siehe #219).
  Future<void> _checkOvertimeWarning(Duration totalOvertime) async {
    // Eine fehlschlagende Warnprüfung darf niemals das eigentliche Speichern
    // der Arbeitszeit gefährden - daher komplett defensiv.
    try {
      final settingsRepository = ref.read(settingsRepositoryProvider);
      final warningType = checkOvertimeWarning(
        totalOvertime: totalOvertime,
        warnOnOvertime: settingsRepository.getWarnOnOvertimeThreshold(),
        overtimeThresholdHours: settingsRepository.getOvertimeThresholdHours(),
        warnOnUndertime: settingsRepository.getWarnOnUndertimeThreshold(),
        undertimeThresholdHours:
            settingsRepository.getUndertimeThresholdHours(),
      );
      if (warningType == OvertimeWarningType.none) return;

      final notificationService = ref.read(notificationServiceProvider);
      await notificationService.showOvertimeWarning(
        type: warningType,
        totalOvertime: totalOvertime,
        l10n: lookupAppLocalizations(Locale(settingsRepository.getLocale())),
      );
    } catch (e) {
      logger
          .w('[Dashboard] Überstunden-Warnung konnte nicht geprüft werden: $e');
    }
  }

  Future<void> setManualStartTime(TimeOfDay time) async {
    if (!await _ensureCurrentDay()) return;
    final oldDate = state.workEntry.workStart ?? state.workEntry.date;
    final newStart = DateTime(
        oldDate.year, oldDate.month, oldDate.day, time.hour, time.minute);
    var updatedEntry = state.workEntry.copyWith(workStart: newStart);

    logger.i('[Dashboard] Setze manuelle Startzeit: $newStart');

    // Berechne automatische Pausen nur wenn:
    // 1. Start UND End vorhanden sind
    // 2. Keine laufende Pause existiert
    // 3. Eintrag ist vom Typ Arbeit (nicht Urlaub/Krank/Feiertag)
    final hasRunningBreak = updatedEntry.breaks.any((b) => b.end == null);
    if (updatedEntry.workStart != null &&
        updatedEntry.workEnd != null &&
        !hasRunningBreak &&
        updatedEntry.type == WorkEntryType.work) {
      logger.i('[Dashboard] Berechne automatische Pausen...');
      updatedEntry =
          BreakCalculatorService.calculateAndApplyBreaks(updatedEntry);
      logger.i(
          '[Dashboard] Automatische Pausen berechnet: ${updatedEntry.breaks.length} Pausen');
    }

    await _recalculateStateAndSave(updatedEntry);
    logger.i('[Dashboard] Startzeit gespeichert');
  }

  Future<void> setManualEndTime(TimeOfDay time) async {
    if (!await _ensureCurrentDay()) return;
    final oldDate = state.workEntry.workEnd ??
        state.workEntry.workStart ??
        state.workEntry.date;
    final newEnd = DateTime(
        oldDate.year, oldDate.month, oldDate.day, time.hour, time.minute);
    var updatedEntry = state.workEntry.copyWith(workEnd: newEnd);

    logger.i('[Dashboard] Setze manuelle Endzeit: $newEnd');

    // Berechne automatische Pausen nur wenn:
    // 1. Start UND End vorhanden sind
    // 2. Keine laufende Pause existiert
    // 3. Eintrag ist vom Typ Arbeit (nicht Urlaub/Krank/Feiertag)
    final hasRunningBreak = updatedEntry.breaks.any((b) => b.end == null);
    if (updatedEntry.workStart != null &&
        updatedEntry.workEnd != null &&
        !hasRunningBreak &&
        updatedEntry.type == WorkEntryType.work) {
      logger.i('[Dashboard] Berechne automatische Pausen...');
      updatedEntry =
          BreakCalculatorService.calculateAndApplyBreaks(updatedEntry);
      logger.i(
          '[Dashboard] Automatische Pausen berechnet: ${updatedEntry.breaks.length} Pausen');
    }

    await _recalculateStateAndSave(updatedEntry);
    logger.i('[Dashboard] Endzeit gespeichert');
  }

  Future<void> clearEndTime() async {
    if (!await _ensureCurrentDay()) return;
    logger.i('[Dashboard] Entferne Endzeit...');

    // Manuelles Kopieren, da copyWith null-Werte ignoriert
    final updatedEntry = WorkEntryEntity(
      id: state.workEntry.id,
      date: state.workEntry.date,
      workStart: state.workEntry.workStart,
      workEnd: null, // Explizit null setzen
      breaks: state.workEntry.breaks,
      manualOvertime: state.workEntry.manualOvertime,
      isManuallyEntered: state.workEntry.isManuallyEntered,
      description: state.workEntry.description,
      type: state.workEntry.type,
    );

    await _recalculateStateAndSave(updatedEntry);
    logger.i('[Dashboard] Endzeit entfernt');
  }

  Future<void> startOrStopBreak() async {
    if (!await _ensureCurrentDay()) return;
    final toggleBreak = ref.read(toggleBreakUseCaseProvider);
    final updatedEntry = await toggleBreak.call(state.workEntry);
    await _recalculateStateAndSave(updatedEntry);
  }

  Future<void> deleteBreak(String breakId) async {
    if (!await _ensureCurrentDay()) return;
    final updatedBreaks =
        state.workEntry.breaks.where((b) => b.id != breakId).toList();
    final updatedEntry = state.workEntry.copyWith(breaks: updatedBreaks);
    await _recalculateStateAndSave(updatedEntry);
  }

  Future<void> updateBreak(BreakEntity breakEntity) async {
    if (!await _ensureCurrentDay()) return;
    final updatedBreaks = state.workEntry.breaks.map((b) {
      return b.id == breakEntity.id ? breakEntity : b;
    }).toList();
    final updatedEntry = state.workEntry.copyWith(breaks: updatedBreaks);
    await _recalculateStateAndSave(updatedEntry);
  }
}

final dashboardViewModelProvider =
    NotifierProvider<DashboardViewModel, DashboardState>(
        DashboardViewModel.new);
