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
    if (isManual) {
      // Epoch-Datum setzen damit _init den gespeicherten Wert als Basis behandelt
      // (nicht als "heutiger Gesamtstand inkl. Daily-Overtime").
      await repository.saveLastUpdateDate(DateTime.utc(1970, 1, 1));
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
