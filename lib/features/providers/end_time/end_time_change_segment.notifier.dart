import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../entities/time_slots.dart';

part 'end_time_change_segment.notifier.g.dart';

@riverpod
class EndTimeChangeSegmentNotifier extends _$EndTimeChangeSegmentNotifier {
  @override
  EndTime build() {
    return EndTime.sixteenClock;
  }

  void setEndTimeChange(EndTime endTime){
    state = endTime;
  }
}