import 'package:equatable/equatable.dart';

import '../../domain/entities/work_entry_entity.dart';

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
      ];
}
