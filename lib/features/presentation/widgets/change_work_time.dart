import 'package:flutter/material.dart';
import 'package:flutter_work_time/features/provider/entities/time_slots.dart';

class ChangeWorkTime extends StatefulWidget {
  const ChangeWorkTime({Key? key}) : super(key: key);

  @override
  State<ChangeWorkTime> createState() => _ChangeWorkTimeState();
}

class _ChangeWorkTimeState extends State<ChangeWorkTime> {
  @override
  Widget build(BuildContext context) {
    Set<WorkTime> timeSlots = <WorkTime>{};
    return Container(
      margin: EdgeInsets.only(left: 16, right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ActionChip(
            label: const Text("Soll Arbeitszeit wählen"),
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
              segments: const <ButtonSegment<WorkTime>>[
                ButtonSegment<WorkTime>(
                  value: WorkTime.sixHour,
                  label: Text('6:00 h'),
                ),
                ButtonSegment<WorkTime>(
                  value: WorkTime.sevenHour,
                  label: Text('7:00 h'),
                ),
                ButtonSegment<WorkTime>(
                  value: WorkTime.sevenHalfHour,
                  label: Text('7:42 h'),
                ),
                ButtonSegment<WorkTime>(
                  value: WorkTime.eightHour,
                  label: Text('8:00 h'),
                ),
              ],
              selected: timeSlots,
              onSelectionChanged: (Set<WorkTime> newSelection) {
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