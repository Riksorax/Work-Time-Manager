import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_work_time/features/providers/break_time/break_time_change_segment.notifier.dart';

import '../../../providers/entities/time_slots.dart';

class ChangeBreakTime extends ConsumerStatefulWidget {
  const ChangeBreakTime({super.key});

  @override
  ConsumerState<ChangeBreakTime> createState() => _ChangeBreakTimeState();
}

class _ChangeBreakTimeState extends ConsumerState<ChangeBreakTime> {
  @override
  Widget build(BuildContext context) {
    BreakTime breakTimeView = ref.watch(breakTimeChangeSegmentNotifierProvider);
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Pausen Zeit wählen"),
          const Divider(),
          const Padding(padding: EdgeInsets.only(bottom: 10)),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton(
              segments: const <ButtonSegment<BreakTime>>[
                ButtonSegment<BreakTime>(
                  value: BreakTime.fifteenMinBreak,
                  label: Text('15 min'),
                ),
                ButtonSegment<BreakTime>(
                  value: BreakTime.thirtyMinBreak,
                  label: Text('30 min'),
                ),
                ButtonSegment<BreakTime>(
                  value: BreakTime.fortyFiveMinuteBreak,
                  label: Text('45 min'),
                ),
                ButtonSegment<BreakTime>(
                  value: BreakTime.sixtyMinuteBreak,
                  label: Text('60 min'),
                ),
              ],
              selected: <BreakTime>{breakTimeView},
              onSelectionChanged: (Set<BreakTime> newSelection) {
                ref.read(breakTimeChangeSegmentNotifierProvider.notifier)
                    .setBreakTimeChange(newSelection.first);
              },
              emptySelectionAllowed: true,
            ),
          ),
        ],
      ),
    );
  }
}