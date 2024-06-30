import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/break_time/break_time_change_manual.notifier.dart';
import '../../../providers/calculate_work_end_time/calculate_end_time.provider.dart';

class ChangeBreakTimeManual extends ConsumerStatefulWidget {
  const ChangeBreakTimeManual({super.key});

  @override
  ConsumerState<ChangeBreakTimeManual> createState() =>
      _ChangeBreakTimeManualState();
}

class _ChangeBreakTimeManualState extends ConsumerState<ChangeBreakTimeManual> {
  @override
  Widget build(BuildContext context) {
    ref.watch(breakTimeChangeManualNotifierProvider.notifier).getBreakTime()☻
    ;
    final defaultBreakTime = ref.read(breakTimeChangeManualNotifierProvider);
    String minuteString = defaultBreakTime.minute.toString();
    String hourString = defaultBreakTime.hour.toString();
    return TextButton(
      child: defaultBreakTime.minute == 0
          ? Text("$hourString Std")
          : defaultBreakTime.hour > 0
              ? Text("$hourString Std $minuteString min")
              : Text("$minuteString min"),
      onPressed: () async {
        int hour = defaultBreakTime.hour;
        int minute = defaultBreakTime.minute;
        final selectedTime = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(
            hour: hour,
            minute: minute,
          ),
          cancelText: "Abbrechen",
          helpText: "Pause",
          hourLabelText: "Stunden",
          minuteLabelText: "Minuten",
        );
        ref
            .read(breakTimeChangeManualNotifierProvider.notifier)
            .setBreakTimeManual(selectedTime!);
        ref.watch(calculateEndTimeProvider.notifier)
            .setCalculateEndTime();
      },
    );
  }
}
