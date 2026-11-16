import 'package:equatable/equatable.dart';

import '../../domain/entities/overtime_freshness.dart';
import '../../domain/entities/work_entry_entity.dart';

/// Der heutige Eintrag ließ sich nicht laden (#573). Angemeldet kommt er nur
/// über die API; das Dashboard zeigt dann einen Hinweis mit „Erneut
/// versuchen“ und sperrt die Eingaben, bis der Tag geladen ist.
enum DashboardLoadFailure {
  none,

  /// Erwartbarer Netzwerkfehler: „Keine Verbindung“.
  offline,

  /// Anderer Fehler: „Das Dashboard konnte nicht geladen werden.“
  failed,
}

class DashboardState extends Equatable {
  final WorkEntryEntity workEntry;
  final Duration elapsedTime;
  final Duration? actualWorkDuration;
  final bool isLoading;
  final Duration? totalOvertime;
  final Duration?
      initialOvertime; // Überstundenstand zu Beginn des Tages/Session
  final Duration? dailyOvertime;
  final Duration? grossWorkDuration; // Brutto-Arbeitszeit (inkl. Pausen)
  final DateTime?
      expectedEndTime; // Voraussichtliche Feierabendzeit für ±0 (Tagesziel)
  final DateTime?
      expectedEndTotalZero; // Voraussichtlicher Feierabend für ±0 (Gesamtbilanz)
  final bool
      isExtraDay; // Zusatztag (mehr Arbeitstage als konfiguriert in dieser Woche)

  /// Eine Schreibaktion des ViewModels läuft (Reentranz-Sperre, #413).
  /// Die UI deaktiviert dann die Schreib-Buttons.
  final bool isSaving;

  /// Herkunft des Saldos in [totalOvertime] (#573): `cached` = ohne Netz der
  /// zuletzt bekannte Stand, `unknown` = ohne Netz und ohne gemerkten Stand
  /// ([totalOvertime] ist dann `null`).
  final OvertimeFreshness overtimeFreshness;

  /// Ladefehler des heutigen Tages (#573).
  final DashboardLoadFailure loadFailure;

  const DashboardState({
    required this.workEntry,
    required this.elapsedTime,
    this.actualWorkDuration,
    this.isLoading = false,
    this.totalOvertime,
    this.initialOvertime,
    this.dailyOvertime,
    this.grossWorkDuration,
    this.expectedEndTime,
    this.expectedEndTotalZero,
    this.isExtraDay = false,
    this.isSaving = false,
    this.overtimeFreshness = OvertimeFreshness.current,
    this.loadFailure = DashboardLoadFailure.none,
  });

  /// [now] ist die Uhr (Default `DateTime.now()`); das ViewModel reicht
  /// seine Uhr aus `clockProvider` durch (#379).
  factory DashboardState.initial({DateTime? now}) {
    final time = now ?? DateTime.now();
    return DashboardState(
      workEntry: WorkEntryEntity(
        id: time.toIso8601String(),
        date: time,
      ),
      elapsedTime: Duration.zero,
      actualWorkDuration: null,
      isLoading: true, // Start with loading
      totalOvertime: null,
      initialOvertime: null,
      dailyOvertime: null,
      grossWorkDuration: null,
      expectedEndTime: null,
      expectedEndTotalZero: null,
      isExtraDay: false,
      isSaving: false,
    );
  }

  DashboardState copyWith({
    WorkEntryEntity? workEntry,
    Duration? elapsedTime,
    Duration? actualWorkDuration,
    bool? isLoading,
    Duration? totalOvertime,
    Duration? initialOvertime,
    Duration? dailyOvertime,
    Duration? grossWorkDuration,
    DateTime? expectedEndTime,
    DateTime? expectedEndTotalZero,
    bool? isExtraDay,
    bool? isSaving,
    OvertimeFreshness? overtimeFreshness,
    DashboardLoadFailure? loadFailure,
  }) {
    return DashboardState(
      workEntry: workEntry ?? this.workEntry,
      elapsedTime: elapsedTime ?? this.elapsedTime,
      actualWorkDuration: actualWorkDuration ?? this.actualWorkDuration,
      isLoading: isLoading ?? this.isLoading,
      totalOvertime: totalOvertime ?? this.totalOvertime,
      initialOvertime: initialOvertime ?? this.initialOvertime,
      dailyOvertime: dailyOvertime ?? this.dailyOvertime,
      grossWorkDuration: grossWorkDuration ?? this.grossWorkDuration,
      expectedEndTime: expectedEndTime ?? this.expectedEndTime,
      expectedEndTotalZero: expectedEndTotalZero ?? this.expectedEndTotalZero,
      isExtraDay: isExtraDay ?? this.isExtraDay,
      isSaving: isSaving ?? this.isSaving,
      overtimeFreshness: overtimeFreshness ?? this.overtimeFreshness,
      loadFailure: loadFailure ?? this.loadFailure,
    );
  }

  @override
  List<Object?> get props => [
        workEntry,
        elapsedTime,
        actualWorkDuration,
        isLoading,
        totalOvertime,
        initialOvertime,
        dailyOvertime,
        grossWorkDuration,
        expectedEndTime,
        expectedEndTotalZero,
        isExtraDay,
        isSaving,
        overtimeFreshness,
        loadFailure,
      ];
}
