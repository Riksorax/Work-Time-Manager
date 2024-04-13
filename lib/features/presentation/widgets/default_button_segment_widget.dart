import 'package:flutter/material.dart';

import 'defeault_button_segment/change_break_time.dart';
import 'defeault_button_segment/change_end_time.dart';
import 'defeault_button_segment/change_start_time.dart';
import 'defeault_button_segment/change_work_time.dart';

class DefaultButtonSegmentWidget extends StatelessWidget {
  const DefaultButtonSegmentWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Padding(
          padding: EdgeInsets.only(top: 16),
        ),
        ChangeStartTime(),
        Padding(
          padding: EdgeInsets.only(bottom: 16, top: 16),
        ),
        ChangeBreakTime(),
        Padding(
          padding: EdgeInsets.only(bottom: 16, top: 16),
        ),
        ChangeWorkTime(),
        Padding(
          padding: EdgeInsets.only(bottom: 16, top: 16),
        ),
        ChangeEndTime(),
        Padding(
          padding: EdgeInsets.only(bottom: 16, top: 16),
        ),
      ],
    );
  }
}
