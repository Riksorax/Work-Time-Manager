import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timer_countdown/flutter_timer_countdown.dart';

import '../../providers/calculate_work_end_time/calculate_work_time_end.notifier.dart';

class WorkTimeEnd extends ConsumerStatefulWidget {
  const WorkTimeEnd({super.key});

  @override
  ConsumerState<WorkTimeEnd> createState() => _WorkTimeEndState();
}

class _WorkTimeEndState extends ConsumerState<WorkTimeEnd> {
  @override
  Widget build(BuildContext context) {
    final workTimeEnd = ref.watch(calculateWorkTimeEndNotifierProvider);
    final workTimeEndHour = workTimeEnd.hour;
    final workTimeEndMinute = workTimeEnd.minute;

    return Row(
      children: [
        Text("Du hast Feierabend in "),
        TimerCountdown(
          endTime: DateTime.now().add(
            Duration(hours: workTimeEndHour, minutes: workTimeEndMinute),
          ),
          format: CountDownTimerFormat.hoursMinutesSeconds,
          enableDescriptions: false,
        ),
      ],
    );
  }
}
