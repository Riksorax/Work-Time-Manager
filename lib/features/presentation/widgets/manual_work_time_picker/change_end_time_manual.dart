import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/calculate_work_end_time/calculate_work_time.provider.dart';
import '../../../providers/end_time/end_time_change_manual.notifier.dart';

class ChangeEndTimeManual extends ConsumerStatefulWidget {
  const ChangeEndTimeManual({super.key});

  @override
  ConsumerState<ChangeEndTimeManual> createState() =>
      _ChangeEndTimeManualState();
}

class _ChangeEndTimeManualState extends ConsumerState<ChangeEndTimeManual> {
  @override
  Widget build(BuildContext context) {
    final defaultEndTime = ref.watch(endTimeChangeManualNotifierProvider);
    String minuteString = defaultEndTime.minute.toString();
    String hourString = defaultEndTime.hour.toString();
    return TextButton(
      child: defaultEndTime.minute == 0
          ? Text("$hourString:${minuteString}0 Uhr")
          : Text("$hourString:$minuteString Uhr"),
      onPressed: () async {
        int hour = defaultEndTime.hour;
        int minute = defaultEndTime.minute;
        final selectedTime = await showTimePicker(
            context: context,
            initialTime: TimeOfDay(
              hour: hour,
              minute: minute,
            ),
            cancelText: "Abbrechen",
            helpText: "End Zeit",
            hourLabelText: "Stunden",
            minuteLabelText: "Minuten");
        ref
            .read(endTimeChangeManualNotifierProvider.notifier)
            .setEndTimeManual(selectedTime!);
        ref.read(calculateWorkTimeProvider.notifier).setCalculateWorkTime();
      },
    );
  }
}
