import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_work_time/core/utils/logger.dart';

import '../../core/providers/providers.dart';
import '../../domain/entities/break_entity.dart';
import '../../domain/entities/work_entry_entity.dart';
import '../../domain/services/break_calculator_service.dart';
import '../../domain/utils/overtime_utils.dart';
import '../state/dashboard_state.dart';

class DashboardViewModel extends Notifier<DashboardState> {
  Timer? _timer;
  Timer? _autoSaveTimer;
  int _tickCounter = 0;
  List<WorkEntryEntity> _weekEntries = [];

  @override
  DashboardState build() {
    // Watch dependencies to trigger rebuild on updates (e.g. Auth change)
    ref.watch(getTodayWorkEntryUseCaseProvider);
    ref.watch(getOvertimeUseCaseProvider);
    ref.watch(settingsRepositoryProvider);

    // Start initial load
    Future.microtask(() => _init());
    return DashboardState.initial();
  }

  Future<void> _init() async {
    logger.i('[Dashboard] Initialisiere Dashboard...');
    final getTodayWorkEntry = ref.read(getTodayWorkEntryUseCaseProvider);
    final overtimeRepository = ref.read(overtimeRepositoryProvider);

    final workEntry = await getTodayWorkEntry.call();
    final storedOvertime = overtimeRepository.getOvertime();
    final lastUpdateDate = overtimeRepository.getLastUpdateDate();

    // Lade Wocheneinträge um zu prüfen ob heute ein Zusatztag ist
    await _loadWeekEntries(workEntry);

    // Berechne dailyOvertime für den initialen Stand
    final targetDailyHours = _getEffectiveTargetDailyHours();
    final isExtraDay = targetDailyHours == Duration.zero;
    Duration initialDailyOvertime = Duration.zero;

    if (workEntry.workStart != null && workEntry.workEnd != null) {
      // Wenn der Tag bereits abgeschlossen ist, berechne Overtime basierend auf dem Eintrag
      final breakDuration = workEntry.breaks.fold<Duration>(
        Duration.zero,
        (previousValue, element) => previousValue + (element.end?.difference(element.start) ?? Duration.zero),
      );
      final actualWorkDuration = workEntry.workEnd!.difference(workEntry.workStart!) - breakDuration;
      initialDailyOvertime = actualWorkDuration - targetDailyHours;
    } else if (workEntry.workStart != null) {
      // Laufender Tag -> Overtime wird im Timer berechnet.
      // Um initialOvertime (Basis) korrekt wiederherzustellen, müssen wir den aktuellen "Tagesfortschritt" vom gespeicherten Gesamtwert abziehen.
      final now = DateTime.now();

      // Berechne aktuelle Pausenzeit
      final breakDuration = _calculateTotalBreakDuration(now);

      // Berechne aktuelle Arbeitszeit (Brutto - Pause)
      final elapsedTime = now.difference(workEntry.workStart!) - breakDuration;

      // Aktueller Überstunden-Stand für heute (wird meist negativ sein, da Tag noch läuft)
      initialDailyOvertime = elapsedTime - targetDailyHours;
    }

    Duration initialOvertime;
    if (lastUpdateDate != null && DateUtils.isSameDay(lastUpdateDate, DateTime.now())) {
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

    logger.i('[Dashboard] Geladener WorkEntry - Start: ${workEntry.workStart}, End: ${workEntry.workEnd}');
    logger.i('[Dashboard] Overtime Init: Stored=$storedOvertime, InitialBase=$initialOvertime, Daily=$initialDailyOvertime, Total=$totalOvertime, ExtraDay=$isExtraDay');

    state = state.copyWith(
      workEntry: workEntry,
      isLoading: false,
      totalOvertime: totalOvertime,
      initialOvertime: initialOvertime,
      dailyOvertime: initialDailyOvertime,
      isExtraDay: isExtraDay,
    );
    _recalculateStateAndSave(workEntry, save: false);
    _startTimerIfNeeded();
  }

  /// Lädt die Einträge für die aktuelle Woche, um zu bestimmen ob heute ein Zusatztag ist.
  Future<void> _loadWeekEntries(WorkEntryEntity todayEntry) async {
    try {
      final workRepository = ref.read(workRepositoryProvider);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final startOfWeek = today.subtract(Duration(days: today.weekday - 1));

      // Einträge des aktuellen Monats laden
      var entries = await workRepository.getWorkEntriesForMonth(now.year, now.month);

      // Falls die Woche in den vorherigen Monat reicht, auch dessen Einträge laden
      if (startOfWeek.month != now.month) {
        final prevEntries = await workRepository.getWorkEntriesForMonth(
            startOfWeek.year, startOfWeek.month);
        entries = [...prevEntries, ...entries];
      }

      // Für aktuelle Woche filtern
      _weekEntries = getWeekEntriesForDate(now, entries);

      // Heutigen Eintrag hinzufügen falls noch nicht enthalten (z.B. neuer Tag)
      final todayInEntries = _weekEntries.any((e) =>
          e.date.year == today.year &&
          e.date.month == today.month &&
          e.date.day == today.day);
      if (!todayInEntries && todayEntry.workStart != null) {
        _weekEntries = [..._weekEntries, todayEntry];
      }
    } catch (e) {
      logger.e('[Dashboard] Fehler beim Laden der Wocheneinträge: $e');
      _weekEntries = [];
    }
  }

  /// Berechnet das effektive Tages-Soll unter Berücksichtigung von Zusatztagen.
  Duration _getEffectiveTargetDailyHours() {
    final settingsRepository = ref.read(settingsRepositoryProvider);
    final workdaysPerWeek = settingsRepository.getWorkdaysPerWeek();
    if (workdaysPerWeek <= 0) return Duration.zero;
    final regularDailyTarget = Duration(
      microseconds: (settingsRepository.getTargetWeeklyHours() /
              workdaysPerWeek *
              Duration.microsecondsPerHour)
          .round(),
    );
    return getEffectiveDailyTarget(
      date: DateTime.now(),
      weekEntries: _weekEntries,
      workdaysPerWeek: workdaysPerWeek,
      regularDailyTarget: regularDailyTarget,
    );
  }

  void updateOvertimeFromSettings(Duration newOvertime) {
    // Wenn Overtime manuell gesetzt wird, ist das der neue Total/Base Wert.
    // Wir setzen Base auf den neuen Wert und behalten Daily bei.
    // Total = Base + Daily.
    // Aber wenn der User "Total" editiert, meint er meistens "Total inkl. heute".
    // Angenommen er setzt Total auf X.
    // Dann ist Base = X - Daily.
    final currentDaily = state.dailyOvertime ?? Duration.zero;
    state = state.copyWith(
      initialOvertime: newOvertime - currentDaily,
      totalOvertime: newOvertime,
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
      final now = DateTime.now();
      final initialElapsedTime = _calculateElapsedTime();
      final initialGrossDuration = now.difference(state.workEntry.workStart!);
      
      state = state.copyWith(
        elapsedTime: initialElapsedTime,
        grossWorkDuration: initialGrossDuration,
      );
      _recalculateOvertime();
      
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        final now = DateTime.now();
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
          _autoSave();
        }
      });
    } else {
      logger.i('[Dashboard] Timer nicht gestartet (Start: ${state.workEntry.workStart}, End: ${state.workEntry.workEnd})');
    }
  }

  Future<void> _autoSave() async {
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

  Duration _calculateElapsedTime() {
    if (state.workEntry.workStart == null) return Duration.zero;
    final now = DateTime.now();
    final breakDuration = _calculateTotalBreakDuration(now);
    return now.difference(state.workEntry.workStart!) - breakDuration;
  }

  void _recalculateOvertime() {
    if (state.workEntry.workStart == null) return;

    final targetDailyHours = _getEffectiveTargetDailyHours();
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
    final Duration targetForTotalZero = remainingForTotalZero.isNegative ? Duration.zero : remainingForTotalZero;
    final expectedEndTotalZero = _calculateExpectedEndTime(targetForTotalZero);

    state = state.copyWith(
      dailyOvertime: dailyOvertime,
      totalOvertime: total,
      expectedEndTime: expectedEndTime,
      expectedEndTotalZero: expectedEndTotalZero,
    );
  }

  /// Berechnet die voraussichtliche Feierabendzeit für ±0 heutige Überstunden
  DateTime? _calculateExpectedEndTime(Duration targetDailyHours) {
    if (state.workEntry.workStart == null) return null;

    final start = state.workEntry.workStart!;
    final now = DateTime.now();
    
    // Bereits genommene Pausen (bis jetzt)
    var currentBreaks = _calculateTotalBreakDuration(now);
    
    // Iterative Berechnung, da zusätzliche Pausen die Brutto-Zeit erhöhen
    // und dadurch ggf. weitere Pausenregeln greifen (z.B. Sprung über 9h).
    var projectedEnd = start.add(targetDailyHours).add(currentBreaks);
    
    for (int i = 0; i < 2; i++) { // Max 2 Iterationen reichen für 6h/9h Regeln
      final grossDuration = projectedEnd.difference(start);
      Duration requiredBreaks = Duration.zero;

      if (grossDuration >= BreakCalculatorService.minWorkTimeForSecondBreak) {
        requiredBreaks = BreakCalculatorService.requiredBreakTimeForLongDay; // 45 min
      } else if (grossDuration >= BreakCalculatorService.minWorkTimeForFirstBreak) {
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

  Duration _calculateTotalBreakDuration(DateTime now) {
    return state.workEntry.breaks.fold(Duration.zero, (prev, b) {
      if (b.start.isAfter(now)) return prev;
      final end = b.end ?? now;
      return prev + end.difference(b.start);
    });
  }

  Future<void> startOrStopTimer() async {
    final now = DateTime.now();
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

      // Berechne automatische Pausen beim Beenden (nur wenn keine Pause läuft)
      final hasRunningBreak = updatedEntry.breaks.any((b) => b.end == null);
      if (!hasRunningBreak) {
        logger.i('[Dashboard] Berechne automatische Pausen...');
        updatedEntry = BreakCalculatorService.calculateAndApplyBreaks(updatedEntry);
        logger.i('[Dashboard] Automatische Pausen berechnet: ${updatedEntry.breaks.length} Pausen');
      } else {
        logger.i('[Dashboard] Automatische Pausen übersprungen: Pause läuft noch');
      }
    } else {
      // Arbeit wurde bereits beendet - Benutzer muss entscheiden
      // Diese Methode wird vom UI mit dem gewählten Modus aufgerufen
      logger.i('[Dashboard] Arbeit bereits beendet - Benutzer muss Aktion wählen');
      return; // UI zeigt Dialog an
    }

    await _recalculateStateAndSave(updatedEntry);
  }

  /// Startet eine komplett neue Session (Start, End und Pausen zurücksetzen)
  Future<void> startNewSession() async {
    final now = DateTime.now();
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
    logger.i('[Dashboard] Komplett neue Session gestartet um $now (Start, End, Pausen zurückgesetzt)');
    await _recalculateStateAndSave(updatedEntry);
  }

  /// Neue Session mit Pausen behalten (nur Start und Endzeit zurücksetzen)
  Future<void> startNewSessionKeepBreaks() async {
    final now = DateTime.now();
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

  Future<void> _recalculateStateAndSave(WorkEntryEntity updatedEntry, {bool save = true}) async {
    Duration? newActualWorkDuration;
    Duration? newTotalOvertime = state.totalOvertime;
    Duration? dailyOvertime;

    Duration? newGrossWorkDuration;
    if (updatedEntry.workStart != null && updatedEntry.workEnd != null) {
      newGrossWorkDuration = updatedEntry.workEnd!.difference(updatedEntry.workStart!);

      final breakDuration = updatedEntry.breaks.fold<Duration>(
        Duration.zero,
        (previousValue, element) => previousValue + (element.end?.difference(element.start) ?? Duration.zero),
      );
      newActualWorkDuration = updatedEntry.workEnd!.difference(updatedEntry.workStart!) - breakDuration;

      final targetDailyHours = _getEffectiveTargetDailyHours();
      dailyOvertime = newActualWorkDuration - targetDailyHours;

      // Total = Base + Daily
      final base = state.initialOvertime ?? Duration.zero;
      newTotalOvertime = base + dailyOvertime;

      if (save) {
        logger.i('[Dashboard] Speichere Overtime: Base=$base, Daily=$dailyOvertime, NewTotal=$newTotalOvertime');
        
        final overtimeRepository = ref.read(overtimeRepositoryProvider);
        await overtimeRepository.saveOvertime(newTotalOvertime);
        await overtimeRepository.saveLastUpdateDate(DateTime.now());
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
    );

    if (save) {
      logger.i('[Dashboard] Speichere WorkEntry: ${updatedEntry.id}, Start: ${updatedEntry.workStart}, End: ${updatedEntry.workEnd}');
      final saveWorkEntry = ref.read(saveWorkEntryUseCaseProvider);
      await saveWorkEntry.call(updatedEntry);
      logger.i('[Dashboard] WorkEntry erfolgreich gespeichert');
    }
    _startTimerIfNeeded();
  }

  Future<void> setManualStartTime(TimeOfDay time) async {
    final oldDate = state.workEntry.workStart ?? DateTime.now();
    final newStart = DateTime(oldDate.year, oldDate.month, oldDate.day, time.hour, time.minute);
    var updatedEntry = state.workEntry.copyWith(workStart: newStart);

    logger.i('[Dashboard] Setze manuelle Startzeit: $newStart');

    // Berechne automatische Pausen nur wenn:
    // 1. Start UND End vorhanden sind
    // 2. Keine laufende Pause existiert
    final hasRunningBreak = updatedEntry.breaks.any((b) => b.end == null);
    if (updatedEntry.workStart != null && updatedEntry.workEnd != null && !hasRunningBreak) {
      logger.i('[Dashboard] Berechne automatische Pausen...');
      updatedEntry = BreakCalculatorService.calculateAndApplyBreaks(updatedEntry);
      logger.i('[Dashboard] Automatische Pausen berechnet: ${updatedEntry.breaks.length} Pausen');
    }

    await _recalculateStateAndSave(updatedEntry);
    logger.i('[Dashboard] Startzeit gespeichert');
  }

  Future<void> setManualEndTime(TimeOfDay time) async {
    final oldDate = state.workEntry.workEnd ?? state.workEntry.workStart ?? DateTime.now();
    final newEnd = DateTime(oldDate.year, oldDate.month, oldDate.day, time.hour, time.minute);
    var updatedEntry = state.workEntry.copyWith(workEnd: newEnd);

    logger.i('[Dashboard] Setze manuelle Endzeit: $newEnd');

    // Berechne automatische Pausen nur wenn:
    // 1. Start UND End vorhanden sind
    // 2. Keine laufende Pause existiert
    final hasRunningBreak = updatedEntry.breaks.any((b) => b.end == null);
    if (updatedEntry.workStart != null && updatedEntry.workEnd != null && !hasRunningBreak) {
      logger.i('[Dashboard] Berechne automatische Pausen...');
      updatedEntry = BreakCalculatorService.calculateAndApplyBreaks(updatedEntry);
      logger.i('[Dashboard] Automatische Pausen berechnet: ${updatedEntry.breaks.length} Pausen');
    }

    await _recalculateStateAndSave(updatedEntry);
    logger.i('[Dashboard] Endzeit gespeichert');
  }

  Future<void> clearEndTime() async {
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
    final toggleBreak = ref.read(toggleBreakUseCaseProvider);
    final updatedEntry = await toggleBreak.call(state.workEntry);
    await _recalculateStateAndSave(updatedEntry);
  }

  Future<void> deleteBreak(String breakId) async {
    final updatedBreaks = state.workEntry.breaks.where((b) => b.id != breakId).toList();
    final updatedEntry = state.workEntry.copyWith(breaks: updatedBreaks);
    await _recalculateStateAndSave(updatedEntry);
  }

  Future<void> updateBreak(BreakEntity breakEntity) async {
    final updatedBreaks = state.workEntry.breaks.map((b) {
      return b.id == breakEntity.id ? breakEntity : b;
    }).toList();
    final updatedEntry = state.workEntry.copyWith(breaks: updatedBreaks);
    await _recalculateStateAndSave(updatedEntry);
  }
}

final dashboardViewModelProvider = NotifierProvider<DashboardViewModel, DashboardState>(DashboardViewModel.new);
