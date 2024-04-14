import 'package:flutter/material.dart';
import 'package:flutter_work_time/features/providers/calculate_work_end_time/calculate_end_time.provider.dart';
import 'package:flutter_work_time/features/providers/entities/time_slots.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'end_time_change_segment.notifier.dart';

part 'end_time_change_manual.notifier.g.dart';

@riverpod
class EndTimeChangeManualNotifier extends _$EndTimeChangeManualNotifier {
  @override
  TimeOfDay build() {
    final calculateEndTime = ref.read(calculateEndTimeProvider.notifier)
        .calculateEnd();
    return calculateEndTime;
  }

  void setEndTimeManual(TimeOfDay choseTimeOfDay) {
    state = choseTimeOfDay;
  }

  void getEndTimeChangeSegment(){
    EndTime endTimeView = ref.watch(endTimeChangeSegmentNotifierProvider.notifier).state;
    switch(endTimeView) {
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
}
