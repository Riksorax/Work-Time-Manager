import 'package:flutter/material.dart';
import 'widgets/default_button_segment_widget.dart';
import 'widgets/manual_time_picker.dart';

class WorkTimeScreen extends StatelessWidget {
  const WorkTimeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        DefaultButtonSegmentWidget(),
        ManualTimePicker(),
      ],
    );
  }
}
