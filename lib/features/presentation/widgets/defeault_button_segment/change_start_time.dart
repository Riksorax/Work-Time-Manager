import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/calculate_work_end_time/calculate_end_time.provider.dart';
import '../../../providers/entities/time_slots.dart';
import '../../../providers/start_time/start_time_change_manual.notifier.dart';
import '../../../providers/start_time/start_time_change_segment.notifier.dart';

class ChangeStartTime extends ConsumerStatefulWidget {
  const ChangeStartTime({super.key});

  @override
  ConsumerState<ChangeStartTime> createState() => _ChangeStartTimeState();
}

class _ChangeStartTimeState extends ConsumerState<ChangeStartTime> {
  @override
  Widget build(BuildContext context) {
    StartTime startTimeView = ref.watch(startTimeChangeSegmentNotifierProvider);
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Start zeit wählen"),
          const Divider(),
          const Padding(padding: EdgeInsets.only(bottom: 10)),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton(
              segments: const <ButtonSegment<StartTime>>[
                ButtonSegment<StartTime>(
                  value: StartTime.sixClock,
                  label: Text('6:00 Uhr'),
                ),
                ButtonSegment<StartTime>(
                  value: StartTime.sevenClock,
                  label: Text('7:00 Uhr'),
                ),
                ButtonSegment<StartTime>(
                  value: StartTime.eightClock,
                  label: Text('8:00 Uhr'),
                ),
                ButtonSegment<StartTime>(
                  value: StartTime.nineClock,
                  label: Text('9:00 Uhr'),
                ),
              ],
              selected: <StartTime>{startTimeView},
              onSelectionChanged: (Set<StartTime> newSelection) {
                ref
                    .read(startTimeChangeSegmentNotifierProvider.notifier)
                    .setStartTimeChange(newSelection.first);
                ref
                    .read(startTimeChangeManualNotifierProvider.notifier)
                    .getStartTimeChangeSegment();
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
