import 'package:flutter/material.dart';
import 'package:flutter_work_time/features/providers/entities/time_slots.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'work_time_change_segment.notifier.dart';

part 'work_time_change_manual.notifier.g.dart';

@riverpod
class WorkTimeChangeManualNotifier extends _$WorkTimeChangeManualNotifier {
  @override
  TimeOfDay build() {
    return const TimeOfDay(hour: 7, minute: 26);
  }

  void setWorkTimeManual(TimeOfDay choseTimeOfDay) {
    state = choseTimeOfDay;
  }

  void getWorkTimeChangeSegment(){
    WorkTime workTimeView = ref.watch(workTimeChangeSegmentNotifierProvider.notifier).state;
    switch(workTimeView) {
      case WorkTime.sixHour:
        state = const TimeOfDay(hour: 6, minute: 00);
        break;
      case WorkTime.sevenHour:
        state = const TimeOfDay(hour: 7, minute: 00);
        break;
      case WorkTime.sevenTwentySixHour:
        state = const TimeOfDay(hour: 7, minute: 26);
        break;
      case WorkTime.eightHour:
        state = const TimeOfDay(hour: 8, minute: 00);
        break;
      default:
        state = const TimeOfDay(hour: 7, minute: 42);
    }

  }
}
