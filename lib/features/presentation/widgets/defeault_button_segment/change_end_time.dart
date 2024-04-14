import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_work_time/features/providers/end_time/end_time_change_segment.notifier.dart';

import '../../../providers/end_time/end_time_change_manual.notifier.dart';
import '../../../providers/entities/time_slots.dart';

class ChangeEndTime extends ConsumerStatefulWidget {
  const ChangeEndTime({super.key});

  @override
  ConsumerState<ChangeEndTime> createState() => _ChangeEndTimeState();
}

class _ChangeEndTimeState extends ConsumerState<ChangeEndTime> {
  @override
  Widget build(BuildContext context) {
    EndTime endTimeView = ref.watch(endTimeChangeSegmentNotifierProvider);
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("End Zeit wählen"),
          const Divider(),
          const Padding(padding: EdgeInsets.only(bottom: 10)),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton(
              segments: const <ButtonSegment<EndTime>>[
                ButtonSegment<EndTime>(
                  value: EndTime.twelveClock,
                  label: Text('12:00 Uhr'),
                ),
                ButtonSegment<EndTime>(
                  value: EndTime.fourteenClock,
                  label: Text('14:00 Uhr'),
                ),
                ButtonSegment<EndTime>(
                  value: EndTime.sixteenClock,
                  label: Text('16:00 Uhr'),
                ),
                ButtonSegment<EndTime>(
                  value: EndTime.seventeenThirtyClock,
                  label: Text('17:30 Uhr'),
                ),
              ],
              selected: <EndTime>{endTimeView},
              onSelectionChanged: (Set<EndTime> newSelection) {
                ref
                    .read(endTimeChangeSegmentNotifierProvider.notifier)
                    .setEndTimeChange(newSelection.first);
                ref
                    .read(endTimeChangeManualNotifierProvider.notifier)
                    .getEndTimeChangeSegment();
              },
              emptySelectionAllowed: true,
            ),
          ),
        ],
      ),
    );
  }
}
