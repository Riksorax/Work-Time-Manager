import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChangeEndTimeManual extends ConsumerStatefulWidget {
  const ChangeEndTimeManual({super.key});

  @override
  ConsumerState<ChangeEndTimeManual> createState() => _ChangeEndTimeManualState();
}

class _ChangeEndTimeManualState extends ConsumerState<ChangeEndTimeManual> {
  @override
  Widget build(BuildContext context) {
    return TextButton(
      child: const Text('17:30 Uhr'),
      onPressed: () {
        showTimePicker(
            context: context,
            initialTime: TimeOfDay.now(),
            cancelText: "Abbrechen",
            helpText: "End Zeit",
            hourLabelText: "Stunden",
            minuteLabelText: "Minuten");
      },
    );
  }
}
