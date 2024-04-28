import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_work_time/features/providers/work_time/work_time_change_segment.notifier.dart';

import '../../../providers/calculate_work_end_time/calculate_end_time.provider.dart';
import '../../../providers/entities/time_slots.dart';
import '../../../providers/work_time/work_time_change_manual.notifier.dart';

class ChangeWorkTime extends ConsumerStatefulWidget {
  const ChangeWorkTime({super.key});

  @override
  ConsumerState<ChangeWorkTime> createState() => _ChangeWorkTimeState();
}

class _ChangeWorkTimeState extends ConsumerState<ChangeWorkTime> {
  @override
  Widget build(BuildContext context) {
    WorkTime workTimeView = ref.watch(workTimeChangeSegmentNotifierProvider);
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Soll Arbeitszeit wählen"),
          const Divider(),
          const Padding(padding: EdgeInsets.only(bottom: 10)),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton(
              segments: const <ButtonSegment<WorkTime>>[
                ButtonSegment<WorkTime>(
                  value: WorkTime.sixHour,
                  label: Text('6 h'),
                ),
                ButtonSegment<WorkTime>(
                  value: WorkTime.sevenHour,
                  label: Text('7 h'),
                ),
                ButtonSegment<WorkTime>(
                  value: WorkTime.sevenTwentySixHour,
                  label: Text('7:42 h'),
                ),
                ButtonSegment<WorkTime>(
                  value: WorkTime.eightHour,
                  label: Text('8 h'),
                ),
              ],
              selected: <WorkTime>{workTimeView},
              onSelectionChanged: (Set<WorkTime> newSelection) {
                ref
                    .read(workTimeChangeSegmentNotifierProvider.notifier)
                    .setWorkTimeChange(newSelection.first);
                ref
                    .read(workTimeChangeManualNotifierProvider.notifier)
                    .getWorkTimeChangeSegment();
                ref.watch(calculateEndTimeProvider.notifier)
                    .setCalculateEndTime();
              },
              emptySelectionAllowed: true,
            ),
          ),
        ],
      ),
    );
  }
}
