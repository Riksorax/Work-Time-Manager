import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_work_time/features/providers/break_time_change.notifier.dart';

import '../../providers/entities/time_slots.dart';

class ChangeBreakTime extends ConsumerStatefulWidget {
  const ChangeBreakTime({Key? key}) : super(key: key);

  @override
  ConsumerState<ChangeBreakTime> createState() => _ChangeBreakTimeState();
}

class _ChangeBreakTimeState extends ConsumerState<ChangeBreakTime> {
  @override
  Widget build(BuildContext context) {
    DateTime defaultBreak = ref.watch(breakTimeChangeNotifierProvider.notifier).state;
    Set<BreakTime> timeSlots = <BreakTime>{};
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
                  value: BreakTime.firstBreak,
                  label: Text('15 min'),
                ),
                ButtonSegment<BreakTime>(
                  value: BreakTime.secondBreak,
                  label: Text('30 min'),
                ),
                ButtonSegment<BreakTime>(
                  value: BreakTime.thirdBreak,
                  label: Text('45 min'),
                ),
                ButtonSegment<BreakTime>(
                  value: BreakTime.fourthBreak,
                  label: Text('60 min'),
                ),
              ],
              selected: timeSlots,
              onSelectionChanged: (Set<BreakTime> newSelection) {
                setState(
                      () {
                    timeSlots = newSelection;
                  },
                );
              },
              emptySelectionAllowed: true,
            ),
          ),
        ],
      ),
    );
  }
}