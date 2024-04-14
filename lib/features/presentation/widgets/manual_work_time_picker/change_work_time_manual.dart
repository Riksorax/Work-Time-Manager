import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/calculate_work_end_time/calculate_end_time.provider.dart';
import '../../../providers/work_time/work_time_change_manual.notifier.dart';

class ChangeWorkTimeManual extends ConsumerStatefulWidget {
  const ChangeWorkTimeManual({super.key});

  @override
  ConsumerState<ChangeWorkTimeManual> createState() =>
      _ChangeWorkTimeManualState();
}

class _ChangeWorkTimeManualState extends ConsumerState<ChangeWorkTimeManual> {
  @override
  Widget build(BuildContext context) {
    final defaultWorkTime = ref.watch(workTimeChangeManualNotifierProvider);
    String minuteString = defaultWorkTime.minute.toString();
    String hourString = defaultWorkTime.hour.toString();
    return TextButton(
      child: defaultWorkTime.minute > 0
          ? Text("$hourString:$minuteString h")
          : Text("$hourString h"),
      onPressed: () async {
        int hour = defaultWorkTime.hour;
        int minute = defaultWorkTime.minute;
        final selectedTime = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.now(),
            cancelText: "Abbrechen",
            helpText: "Arbeits Stunden",
            hourLabelText: "Stunden",
            minuteLabelText: "Minuten");
        ref
            .read(workTimeChangeManualNotifierProvider.notifier)
            .setWorkTimeManual(selectedTime!);
        ref.watch(calculateEndTimeProvider.notifier)
            .setCalculateEndTime();
      },
    );
  }
}
