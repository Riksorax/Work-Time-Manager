import 'package:flutter/material.dart';
import 'package:flutter_work_time/features/provider/entities/time_slots.dart';

class ChangeStartTime extends StatefulWidget {
  const ChangeStartTime({super.key});

  @override
  State<ChangeStartTime> createState() => _ChangeStartTimeState();
}

class _ChangeStartTimeState extends State<ChangeStartTime> {
  @override
  Widget build(BuildContext context) {
    Set<StartTime> timeSlots = <StartTime>{};
    return Container(
      margin: EdgeInsets.only(left: 16, right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ActionChip(
            label: const Text("Start zeit wählen"),
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
              selected: timeSlots,
              onSelectionChanged: (Set<StartTime> newSelection) {
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
