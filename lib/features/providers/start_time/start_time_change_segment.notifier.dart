import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../entities/time_slots.dart';

part 'start_time_change_segment.notifier.g.dart';

@riverpod
class StartTimeChangeSegmentNotifier extends _$StartTimeChangeSegmentNotifier {
  @override
  StartTime build() {
    return StartTime.eightClock;
  }

  void setStartTimeChange(StartTime startTime){
    state = startTime;
  }
}
