import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../entities/time_slots.dart';

part 'work_time_change_segment.notifier.g.dart';

@riverpod
class WorkTimeChangeSegmentNotifier extends _$WorkTimeChangeSegmentNotifier {
  @override
  WorkTime build() {
    return WorkTime.sevenTwentySixHour;
  }

  void setWorkTimeChange(WorkTime workTime){
    state = workTime;
  }
}