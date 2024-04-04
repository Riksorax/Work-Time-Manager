import 'package:flutter/material.dart';
import 'package:flutter_work_time/features/provider/entities/time_slots.dart';

class ManualTimePicker extends StatefulWidget {
  const ManualTimePicker({super.key});

  @override
  State<ManualTimePicker> createState() => _ManualTimePickerState();
}

class _ManualTimePickerState extends State<ManualTimePicker> {
  @override
  Widget build(BuildContext context) {
    Set<ManualTime> timeSlots = <ManualTime>{};
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Zeiten manuell anpassen"),
          const Divider(),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Die Arbeitszeit wird durch Start, "
                      "Pausen und End Zeit automatisch ausgerechnet. "
                      "End Zeit wird automatisch durch Start, "
                      "Pausen und Arbeit Zeit ausgerechnet."),
                  const SizedBox(height: 10),
                  const Text("Zeiten sind manuell änderbar."),
                  const SizedBox(height: 10),
                  const Text("Du machst  xx min/std plus/minus."),
                  const Text("Feierabend in xx std  xx min"),
                  const Padding(padding: EdgeInsets.only(bottom: 10)),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton(
                      segments: const <ButtonSegment<ManualTime>>[
                        ButtonSegment<ManualTime>(
                          value: ManualTime.startTime,
                          label: Text('8:00 Uhr'),
                        ),
                        ButtonSegment<ManualTime>(
                          value: ManualTime.breakTime,
                          label: Text('30 min'),
                        ),
                        ButtonSegment<ManualTime>(
                          value: ManualTime.workHour,
                          label: Text('7,42 h'),
                        ),
                        ButtonSegment<ManualTime>(
                          value: ManualTime.endTime,
                          label: Text('17:30 Uhr'),
                        ),
                      ],
                      selected: timeSlots,
                      onSelectionChanged: (Set<ManualTime> newSelection) {
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
            ),
          ),
        ],
      ),
    );
  }
}
