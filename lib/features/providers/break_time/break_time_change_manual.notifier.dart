import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../shared/providers/shared_prefs_repository.provider.dart';
import '../entities/time_slots.dart';
import 'break_time_change_segment.notifier.dart';

part 'break_time_change_manual.notifier.g.dart';

@riverpod
class BreakTimeChangeManualNotifier extends _$BreakTimeChangeManualNotifier {
  @override
  TimeOfDay build() {
    final savedBreakTime = ref
        .watch(
          GetBreakTimeManualSharedPrefsProvider("BreakTime"),
        )
        .value;
    late TimeOfDay breakTime = const TimeOfDay(hour: 0, minute: 30);
    if (savedBreakTime != null) {
      breakTime = TimeOfDay(
          hour: int.parse(savedBreakTime.split(":")[0]),
          minute: int.parse(savedBreakTime.split(":")[1]));
    } else {
      //saveBreakTime(breakTime);
    }
    return breakTime;
  }

  void setBreakTimeManual(TimeOfDay choseTimeOfDay) {
    state = choseTimeOfDay;
    saveBreakTime(choseTimeOfDay);
  }

  void getBreakTimeChangeSegment() {
    BreakTime breakTimeView =
        ref.watch(breakTimeChangeSegmentNotifierProvider.notifier).state;
    switch (breakTimeView) {
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

  void saveBreakTime(TimeOfDay breakTime) {
    ref.read(
      SaveBreakTimeManualSharedPrefsProvider(
        "BreakTime",
        breakTime.toString(),
      ),
    );
  }
}
