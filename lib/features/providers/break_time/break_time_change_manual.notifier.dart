import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'break_time_change_manual.notifier.g.dart';

@riverpod
class BreakTimeChangeManualNotifier extends _$BreakTimeChangeManualNotifier {
  @override
  TimeOfDay build() {
    return const TimeOfDay(hour: 0, minute: 30);
  }

  void setDateTimeManual(TimeOfDay choseTimeOfDay) {
    state = choseTimeOfDay;
  }
}
