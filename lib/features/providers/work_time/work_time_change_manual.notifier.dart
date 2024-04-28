import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../shared/providers/shared_prefs_repository.provider.dart';
import '../entities/time_slots.dart';
import 'work_time_change_segment.notifier.dart';

part 'work_time_change_manual.notifier.g.dart';

@riverpod
class WorkTimeChangeManualNotifier extends _$WorkTimeChangeManualNotifier {
  @override
  TimeOfDay build() {
    final savedWorkTime = ref
        .watch(
          GetWorkTimeManualSharedPrefsProvider("WorkTime"),
        )
        .value;
    late TimeOfDay workTime = const TimeOfDay(hour: 7, minute: 42);
    if (savedWorkTime != null) {
      workTime = TimeOfDay(
          hour: int.parse(savedWorkTime.split(":")[0]),
          minute: int.parse(savedWorkTime.split(":")[1]));
    } else {
      //saveWorkTime(workTime);
    }
    return workTime;
  }

  void setWorkTimeManual(TimeOfDay choseTimeOfDay) {
    state = choseTimeOfDay;
    //saveWorkTime(choseTimeOfDay);
  }

  void getWorkTimeChangeSegment() {
    WorkTime workTimeView =
        ref.watch(workTimeChangeSegmentNotifierProvider.notifier).state;
    switch (workTimeView) {
      case WorkTime.sixHour:
        state = const TimeOfDay(hour: 6, minute: 00);
        break;
      case WorkTime.sevenHour:
        state = const TimeOfDay(hour: 7, minute: 00);
        break;
      case WorkTime.sevenTwentySixHour:
        state = const TimeOfDay(hour: 7, minute: 42);
        break;
      case WorkTime.eightHour:
        state = const TimeOfDay(hour: 8, minute: 00);
        break;
      default:
        state = const TimeOfDay(hour: 7, minute: 42);
    }
  }

  void saveWorkTime(TimeOfDay workTime) {
    ref.read(
      SaveWorkTimeManualSharedPrefsProvider(
        "WorkTime",
        workTime.toString(),
      ),
    );
  }
}
