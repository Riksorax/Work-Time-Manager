import 'package:flutter/material.dart';
import 'package:flutter_work_time/features/providers/calculate_work_end_time/calculate_end_time.provider.dart';
import 'package:flutter_work_time/features/providers/entities/time_slots.dart';
import 'package:flutter_work_time/features/shared/providers/shared_prefs_repository.provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'end_time_change_segment.notifier.dart';

part 'end_time_change_manual.notifier.g.dart';

@riverpod
class EndTimeChangeManualNotifier extends _$EndTimeChangeManualNotifier {
  @override
  TimeOfDay build() {
    final savedEndTime = ref
        .watch(
          GetEndTimeManualSharedPrefsProvider("EndTime"),
        )
        .value;
    late TimeOfDay endTime =
        ref.read(calculateEndTimeProvider.notifier).calculateEnd();
    if (savedEndTime != null) {
      endTime = TimeOfDay(
          hour: int.parse(savedEndTime.split(":")[0]),
          minute: int.parse(savedEndTime.split(":")[1]));
    } else {
      //saveEndTime(endTime);
    }
    return endTime;
  }

  void setEndTimeManual(TimeOfDay choseTimeOfDay) {
    state = choseTimeOfDay;
    //saveEndTime(choseTimeOfDay);
  }

  void getEndTimeChangeSegment() {
    EndTime endTimeView =
        ref.watch(endTimeChangeSegmentNotifierProvider.notifier).state;
    switch (endTimeView) {
      case EndTime.twelveClock:
        state = const TimeOfDay(hour: 12, minute: 00);
        break;
      case EndTime.fourteenClock:
        state = const TimeOfDay(hour: 14, minute: 00);
        break;
      case EndTime.sixteenClock:
        state = const TimeOfDay(hour: 16, minute: 00);
        break;
      case EndTime.seventeenThirtyClock:
        state = const TimeOfDay(hour: 17, minute: 30);
        break;
      default:
        state = const TimeOfDay(hour: 17, minute: 00);
    }
  }

  void saveEndTime(TimeOfDay endTime) {
    ref.read(
      SaveEndTimeManualSharedPrefsProvider(
        "EndTime",
        endTime.toString(),
      ),
    );
  }
}
