import '../repositories/overtime_repository.dart';
import 'package:flutter/material.dart';

/// Use Case, um den aktuellen Überstundensaldo abzurufen.
class GetOvertime {
  final OvertimeRepository _repository;

  GetOvertime(this._repository);

  Duration call() => _repository.getOvertime();
}

/// Use Case, um den Überstundensaldo zu aktualisieren.
class UpdateOvertime {
  final OvertimeRepository _repository;

  UpdateOvertime(this._repository);

  /// Passt den Saldo um die angegebene [amount] an und speichert ihn.
  Future<Duration> call({required Duration amount}) async {
    final currentOvertime = _repository.getOvertime();
    final newOvertime = currentOvertime + amount;
    await _repository.saveOvertime(newOvertime);
    return newOvertime;
  }
}