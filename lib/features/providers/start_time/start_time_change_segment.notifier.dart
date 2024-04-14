import 'package:flutter_work_time/features/providers/entities/time_slots.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

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
