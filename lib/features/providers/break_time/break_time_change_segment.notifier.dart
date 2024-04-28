import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../entities/time_slots.dart';

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
