import 'package:flutter_work_time/domain/repositories/overtime_repository.dart';

class GetOvertime {
  final OvertimeRepository repository;

  GetOvertime(this.repository);

  Duration call() {
    return repository.getOvertime();
  }
}

class UpdateOvertime {
  final OvertimeRepository repository;

  UpdateOvertime(this.repository);

  Future<Duration> call({required Duration amount}) async {
    final currentOvertime = repository.getOvertime();
    final newOvertime = currentOvertime + amount;
    await repository.saveOvertime(newOvertime);
    return newOvertime;
  }
}

class SetOvertime {
  final OvertimeRepository repository;

  SetOvertime(this.repository);

  Future<void> call({required Duration overtime, bool isManual = false}) async {
    await repository.saveOvertime(overtime);
    // Bei manueller Änderung das Datum speichern
    if (isManual) {
      await repository.saveLastUpdateDate(DateTime.now());
    }
  }
}

class GetLastOvertimeUpdate {
  final OvertimeRepository repository;

  GetLastOvertimeUpdate(this.repository);

  DateTime? call() {
    return repository.getLastUpdateDate();
  }
}
