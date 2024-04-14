import 'package:flutter/material.dart';
import 'package:flutter_work_time/features/providers/entities/time_slots.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'break_time_change_segment.notifier.dart';

part 'break_time_change_manual.notifier.g.dart';

@riverpod
class BreakTimeChangeManualNotifier extends _$BreakTimeChangeManualNotifier {
  @override
  TimeOfDay build() {
    return const TimeOfDay(hour: 0, minute: 30);
  }

  void setBreakTimeManual(TimeOfDay choseTimeOfDay) {
    state = choseTimeOfDay;
  }

  void getBreakTimeChangeSegment(){
    BreakTime breakTimeView = ref.watch(breakTimeChangeSegmentNotifierProvider.notifier).state;
    switch(breakTimeView) {
      case BreakTime.fifteenMinBreak:
        state = const TimeOfDay(hour: 0, minute: 15);
        break;
      case BreakTime.thirtyMinBreak:
        state = const TimeOfDay(hour: 0, minute: 30);
        break;
      case BreakTime.fortyFiveMinuteBreak:
        state = const TimeOfDay(hour: 0, minute: 45);
        break;
      case BreakTime.sixtyMinuteBreak:
        state = const TimeOfDay(hour: 1, minute: 00);
        break;
      default:
        state = const TimeOfDay(hour: 0, minute: 30);
    }

  }
}
