import '../../domain/entities/work_entry_entity.dart';
import '../../domain/repositories/work_repository.dart';

class WorkEntryCheckerService {
  final WorkRepository _workRepository;

  WorkEntryCheckerService(this._workRepository);

  /// Prüft, ob für heute Einträge fehlen
  Future<MissingEntries> checkMissingEntries() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Hole heutigen Eintrag
    final entries = await _workRepository.getWorkEntriesForMonth(today.year, today.month);

    final todayEntry = entries.firstWhere(
      (e) => e.date.year == today.year &&
             e.date.month == today.month &&
             e.date.day == today.day,
      orElse: () => WorkEntryEntity(
        id: '',
        date: today,
        workStart: null,
        workEnd: null,
        breaks: const [],
      ),
    );

    return MissingEntries(
      missingWorkStart: todayEntry.workStart == null,
      missingWorkEnd: todayEntry.workStart != null && todayEntry.workEnd == null,
      missingBreaks: todayEntry.workStart != null &&
                     todayEntry.workEnd != null &&
                     todayEntry.breaks.isEmpty,
    );
  }
}

class MissingEntries {
  final bool missingWorkStart;
  final bool missingWorkEnd;
  final bool missingBreaks;

  MissingEntries({
    required this.missingWorkStart,
    required this.missingWorkEnd,
    required this.missingBreaks,
  });

  bool get hasMissingEntries => missingWorkStart || missingWorkEnd || missingBreaks;

  List<String> getMissingTypes() {
    final missing = <String>[];
    if (missingWorkStart) missing.add('Arbeitsbeginn');
    if (missingWorkEnd) missing.add('Arbeitsende');
    if (missingBreaks) missing.add('Pausen');
    return missing;
  }
}
