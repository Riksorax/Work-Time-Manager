import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../shared/providers/shared_prefs_repository.provider.dart';
import 'calculate_end_time.provider.dart';

part 'calculate_work_time_end.notifier.g.dart';

@riverpod
class CalculateWorkTimeEndNotifier extends _$CalculateWorkTimeEndNotifier {
  @override
  TimeOfDay build() => calculateWorkTimeEnd();

  TimeOfDay calculateWorkTimeEnd(){
    final savedEndTime = ref
        .watch(
      GetEndTimeManualSharedPrefsProvider("EndTime"),
    ).value;
    late TimeOfDay endTime = ref.watch(calculateEndTimeProvider.notifier).calculateEnd();

    if (savedEndTime != null ) {
      endTime = TimeOfDay(
          hour: int.parse(savedEndTime.split(":")[0]),
          minute: int.parse(savedEndTime.split(":")[1]));
    }

    TimeOfDay currentTime = TimeOfDay.now();
    Duration endTimeDuration = Duration(hours: endTime.hour, minutes: endTime.minute);
    Duration currentTimeDuration = Duration(hours: currentTime.hour, minutes: currentTime.minute);

    if (currentTimeDuration <= endTimeDuration) {
      Duration totalTime = currentTimeDuration - endTimeDuration;
      endTime = TimeOfDay(
        hour: totalTime.inHours.remainder(24),
        minute: totalTime.inMinutes.remainder(60),
      );
    }
    else{
      endTime = const TimeOfDay(hour: 00, minute: 00);
    }
    state = endTime;
    return endTime;
  }
}
