import 'package:flutter/material.dart';
import 'package:flutter_work_time/features/presentation/widgets/change_break_time.dart';
import 'package:flutter_work_time/features/presentation/widgets/change_end_time.dart';
import 'package:flutter_work_time/features/presentation/widgets/change_start_time.dart';
import 'package:flutter_work_time/features/presentation/widgets/change_work_time.dart';

class WorkTimeScreen extends StatelessWidget {
  const WorkTimeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        ChangeStartTime(),
        Padding(padding: EdgeInsets.only(bottom: 16),),
        ChangeBreakTime(),
        Padding(padding: EdgeInsets.only(bottom: 16),),
        ChangeWorkTime(),
        Padding(padding: EdgeInsets.only(bottom: 16),),
        ChangeEndTime(),
        Padding(padding: EdgeInsets.only(bottom: 16),),
      ],
    );
  }
}
