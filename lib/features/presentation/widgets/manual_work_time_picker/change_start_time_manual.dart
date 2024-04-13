import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChangeStartTimeManual extends ConsumerStatefulWidget {
  const ChangeStartTimeManual({super.key});

  @override
  ConsumerState<ChangeStartTimeManual> createState() => _ChangeStartTimeManualState();
}

class _ChangeStartTimeManualState extends ConsumerState<ChangeStartTimeManual> {
  @override
  Widget build(BuildContext context) {
    return TextButton(
      child: const Text('8:00 Uhr'),
      onPressed: () {
        showTimePicker(
            context: context,
            initialTime: TimeOfDay.now(),
            cancelText: "Abbrechen",
            helpText: "Start Zeit",
            hourLabelText: "Stunden",
            minuteLabelText: "Minuten");
      },
    );
  }
}
