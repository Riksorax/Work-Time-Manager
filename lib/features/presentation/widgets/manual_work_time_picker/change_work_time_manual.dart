import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChangeWorkTimeManual extends ConsumerStatefulWidget {
  const ChangeWorkTimeManual({super.key});

  @override
  ConsumerState<ChangeWorkTimeManual> createState() => _ChangeWorkTimeManualState();
}

class _ChangeWorkTimeManualState extends ConsumerState<ChangeWorkTimeManual> {
  @override
  Widget build(BuildContext context) {
    return TextButton(
      child: const Text('7,42 h'),
      onPressed: () {
        showTimePicker(
            context: context,
            initialTime: TimeOfDay.now(),
            cancelText: "Abbrechen",
            helpText: "Arbeits Stunden",
            hourLabelText: "Stunden",
            minuteLabelText: "Minuten");
      },
    );
  }
}
