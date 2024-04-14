import 'package:flutter/material.dart';
import 'package:flutter_work_time/features/providers/entities/time_slots.dart';
import 'package:flutter_work_time/features/shared/providers/shared_prefs_repository.provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../calculate_work_end_time/calculate_end_time.provider.dart';
import 'start_time_change_segment.notifier.dart';

part 'start_time_change_manual.notifier.g.dart';

@riverpod
class StartTimeChangeManualNotifier extends _$StartTimeChangeManualNotifier {
  @override
  TimeOfDay build() {
    final savedStartTime = ref
        .watch(
          GetStartTimeManualSharedPrefsProvider("StartTime"),
        )
        .value;
    late TimeOfDay startTime = const TimeOfDay(hour: 8, minute: 00);
    if (savedStartTime != null) {
      startTime = TimeOfDay(
          hour: int.parse(savedStartTime.split(":")[0]),
          minute: int.parse(savedStartTime.split(":")[1]));
    } else {
      //saveStartTime(startTime);
    }
    return startTime;
  }

  void setStartTimeManual(TimeOfDay choseTimeOfDay) {
    state = choseTimeOfDay;
    //saveStartTime(choseTimeOfDay);
  }

  void getStartTimeChangeSegment() {
    StartTime startTimeView =
        ref.watch(startTimeChangeSegmentNotifierProvider.notifier).state;
    switch (startTimeView) {
      case StartTime.sixClock:
        state = const TimeOfDay(hour: 6, minute: 00);
        break;
      case StartTime.sevenClock:
        state = const TimeOfDay(hour: 7, minute: 00);
        break;
      case StartTime.eightClock:
        state = const TimeOfDay(hour: 8, minute: 00);
        break;
      case StartTime.nineClock:
        state = const TimeOfDay(hour: 9, minute: 00);
        break;
      default:
        state = const TimeOfDay(hour: 8, minute: 00);
    }
  }

  void saveStartTime(TimeOfDay startTime) {
    ref.read(
      SaveStartTimeManualSharedPrefsProvider(
        "StartTime",
        startTime.toString(),
      ),
    );
  }
}
