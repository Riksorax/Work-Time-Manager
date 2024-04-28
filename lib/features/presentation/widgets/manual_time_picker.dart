import 'package:flutter/material.dart';

import 'manual_work_time_picker/change_break_time_manual.dart';
import 'manual_work_time_picker/change_end_time_manual.dart';
import 'manual_work_time_picker/change_start_time_manual.dart';
import 'manual_work_time_picker/change_work_time_manual.dart';

class ManualTimePicker extends StatefulWidget {
  const ManualTimePicker({super.key});

  @override
  State<ManualTimePicker> createState() => _ManualTimePickerState();
}

class _ManualTimePickerState extends State<ManualTimePicker> {

  @override
  Widget build(BuildContext context) {

    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Zeiten manuell anpassen"),
          Divider(),
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Die Arbeitszeit wird durch Start, "
                      "Pausen und End Zeit automatisch ausgerechnet. "
                      "End Zeit wird automatisch durch Start, "
                      "Pausen und Arbeit Zeit ausgerechnet."),
                  SizedBox(height: 10),
                  Text("Zeiten sind manuell änderbar."),
                  SizedBox(height: 10),
                  Text("Du machst  xx min/std plus/minus."),
                  Text("Feierabend in xx std  xx min"),
                  Padding(padding: EdgeInsets.only(bottom: 10)),
                  SizedBox(
                    width: double.infinity,
                    child: Column(
                      children: [
                        OverflowBar(
                          children: [
                            ChangeStartTimeManual(),
                            ChangeBreakTimeManual(),
                            ChangeWorkTimeManual(),
                            ChangeEndTimeManual(),
                          ],
                        )
                      ],
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
