import 'package:flutter_work_time/features/providers/entities/time_slots.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'break_time_change_segment.notifier.g.dart';

@riverpod
class BreakTimeChangeSegmentNotifier extends _$BreakTimeChangeSegmentNotifier {
  @override
  BreakTime build() {
    return BreakTime.thirtyMinBreak;
  }

  void setBreakTimeChange(BreakTime breakTime) {
    state = breakTime;
  }
}
