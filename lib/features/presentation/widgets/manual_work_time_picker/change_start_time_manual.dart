import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/calculate_work_end_time/calculate_end_time.provider.dart';
import '../../../providers/start_time/start_time_change_manual.notifier.dart';

class ChangeStartTimeManual extends ConsumerStatefulWidget {
  const ChangeStartTimeManual({super.key});

  @override
  ConsumerState<ChangeStartTimeManual> createState() => _ChangeStartTimeManualState();
}

class _ChangeStartTimeManualState extends ConsumerState<ChangeStartTimeManual> {
  @override
  Widget build(BuildContext context) {
    final defaultStartTime = ref.watch(startTimeChangeManualNotifierProvider);
    String minuteString = defaultStartTime.minute.toString();
    String hourString = defaultStartTime.hour.toString();
    return TextButton(
      child: defaultStartTime.minute == 0 ? Text("$hourString:${minuteString}0 Uhr") : Text("$hourString:$minuteString Uhr"),
      onPressed: () async {
        int hour = defaultStartTime.hour;
        int minute = defaultStartTime.minute;
        final selectedTime = await showTimePicker(
            context: context,
            initialTime: TimeOfDay(
              hour: hour,
              minute: minute,
            ),
            cancelText: "Abbrechen",
            helpText: "Start Zeit",
            hourLabelText: "Stunden",
            minuteLabelText: "Minuten");
        ref
            .read(startTimeChangeManualNotifierProvider.notifier)
            .setStartTimeManual(selectedTime!);
        ref.watch(calculateEndTimeProvider.notifier)
            .setCalculateEndTime();

      },
    );
  }
}
