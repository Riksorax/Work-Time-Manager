import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../break_time/break_time_change_manual.notifier.dart';
import '../end_time/end_time_change_manual.notifier.dart';
import '../start_time/start_time_change_manual.notifier.dart';
import '../work_time/work_time_change_manual.notifier.dart';

part 'calculate_end_time.provider.g.dart';

@riverpod
class CalculateEndTime extends _$CalculateEndTime {
  @override
  TimeOfDay build() {
    return const TimeOfDay(hour: 16, minute: 30);
  }

  TimeOfDay calculateEnd(){
    final startTime = ref.watch(startTimeChangeManualNotifierProvider);
    final breakTime = ref.watch(breakTimeChangeManualNotifierProvider);
    final workTime = ref.watch(workTimeChangeManualNotifierProvider);
    Duration startTimeDuration = Duration(hours: startTime.hour, minutes: startTime.minute);
    Duration breakTimeDuration = Duration(hours: breakTime.hour, minutes: breakTime.minute);
    Duration workTimeDuration = Duration(hours: workTime.hour, minutes: workTime.minute);
    Duration totalTimeWithoutBreak = startTimeDuration + workTimeDuration;
    Duration endTimeDuration = totalTimeWithoutBreak + breakTimeDuration;
    TimeOfDay endTime = TimeOfDay(
      hour: endTimeDuration.inHours.remainder(24),
      minute: endTimeDuration.inMinutes.remainder(60),
    );
    ref.read(startTimeChangeManualNotifierProvider.notifier).saveStartTime(startTime);
    ref.read(breakTimeChangeManualNotifierProvider.notifier).saveBreakTime(breakTime);
    ref.read(workTimeChangeManualNotifierProvider.notifier).saveWorkTime(workTime);
    return endTime;
  }

  void setCalculateEndTime(){
    final endTime = calculateEnd();
    ref.read(endTimeChangeManualNotifierProvider.notifier).setEndTimeManual(endTime);
  }
}
