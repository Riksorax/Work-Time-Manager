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
