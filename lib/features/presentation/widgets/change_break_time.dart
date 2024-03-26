import 'package:flutter/material.dart';
import 'package:flutter_work_time/features/provider/entities/time_slots.dart';

class ChangeBreakTime extends StatefulWidget {
  const ChangeBreakTime({Key? key}) : super(key: key);

  @override
  _ChangeBreakTimeState createState() => _ChangeBreakTimeState();
}

class _ChangeBreakTimeState extends State<ChangeBreakTime> {
  @override
  Widget build(BuildContext context) {
    Set<BreakTime> timeSlots = <BreakTime>{};
    return Container(
      margin: EdgeInsets.only(left: 16, right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ActionChip(
            label: const Text("Pausen Zeit wählen"),
            avatar: const Icon(Icons.alarm),
            onPressed: () {
              showTimePicker(
                context: context,
                initialTime: TimeOfDay.now(),
              );
            },
          ),
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