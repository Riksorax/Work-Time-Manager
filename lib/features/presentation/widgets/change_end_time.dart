import 'package:flutter/material.dart';
import 'package:flutter_work_time/features/provider/entities/time_slots.dart';

class ChangeEndTime extends StatefulWidget {
  const ChangeEndTime({Key? key}) : super(key: key);

  @override
  _ChangeEndTimeState createState() => _ChangeEndTimeState();
}

class _ChangeEndTimeState extends State<ChangeEndTime> {
  @override
  Widget build(BuildContext context) {
    Set<EndTime> timeSlots = <EndTime>{};
    return Container(
      margin: EdgeInsets.only(left: 16, right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ActionChip(
            label: const Text("End Zeit wählen"),
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
              segments: const <ButtonSegment<EndTime>>[
                ButtonSegment<EndTime>(
                  value: EndTime.t,
                  label: Text('12:00 Uhr'),
                ),
                ButtonSegment<EndTime>(
                  value: EndTime.eightHour,
                  label: Text('14:00 Uhr'),
                ),
                ButtonSegment<EndTime>(
                  value: EndTime.sevenHalfHour,
                  label: Text('16:00 Uhr'),
                ),
                ButtonSegment<EndTime>(
                  value: EndTime.sevenHour,
                  label: Text('18:00 Uhr'),
                ),
              ],
              selected: timeSlots,
              onSelectionChanged: (Set<EndTime> newSelection) {
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
