import 'package:flutter/material.dart';
import 'package:flutter_work_time/features/presentation/widgets/default_button_segment_widget.dart';
import 'package:flutter_work_time/features/presentation/widgets/defeault_button_segment/change_break_time.dart';
import 'package:flutter_work_time/features/presentation/widgets/defeault_button_segment/change_end_time.dart';
import 'package:flutter_work_time/features/presentation/widgets/manual_time_picker.dart';

import 'widgets/defeault_button_segment/change_start_time.dart';
import 'widgets/defeault_button_segment/change_work_time.dart';

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
