import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../break_time/break_time_change_manual.notifier.dart';
import '../end_time/end_time_change_manual.notifier.dart';
import '../start_time/start_time_change_manual.notifier.dart';
import '../work_time/work_time_change_manual.notifier.dart';

part 'calculate_work_time.provider.g.dart';

@riverpod
class CalculateWorkTime extends _$CalculateWorkTime {
  @override
  TimeOfDay build() {
    return TimeOfDay.now();
  }

  TimeOfDay calculateWork(){
    final startTime = ref.watch(startTimeChangeManualNotifierProvider);
    final breakTime = ref.watch(breakTimeChangeManualNotifierProvider);
    final endTime = ref.watch(endTimeChangeManualNotifierProvider);
    Duration startTimeDuration = Duration(hours: startTime.hour, minutes: startTime.minute);
    Duration breakTimeDuration = Duration(hours: breakTime.hour, minutes: breakTime.minute);
    Duration endTimeDuration = Duration(hours: endTime.hour, minutes: endTime.minute);
    Duration totalTimeWithoutBreak = endTimeDuration - startTimeDuration;
    Duration workTimeDuration = totalTimeWithoutBreak - breakTimeDuration;
    TimeOfDay workTime = TimeOfDay(
      hour: workTimeDuration.inHours.remainder(24),
      minute: workTimeDuration.inMinutes.remainder(60),
    );
    return workTime;
  }

  void setCalculateWorkTime(){
    final workTime = calculateWork();
    ref.read(workTimeChangeManualNotifierProvider.notifier).setWorkTimeManual(workTime);
  }
}
