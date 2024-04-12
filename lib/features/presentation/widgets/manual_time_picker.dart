import 'package:flutter/material.dart';

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
                    child: Column(
                      children: [
                        OverflowBar(
                          children: [
                            TextButton(
                              child: const Text('8:00 Uhr'),
                              onPressed: () {
                                showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.now(),
                                    cancelText: "Abbrechen",
                                    helpText: "Start Zeit",
                                    hourLabelText: "Stunden",
                                    minuteLabelText: "Minuten");
                              },
                            ),
                            TextButton(
                              child: const Text('30 min'),
                              onPressed: () {
                                showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.now(),
                                    cancelText: "Abbrechen",
                                    helpText: "Pause",
                                    hourLabelText: "Stunden",
                                    minuteLabelText: "Minuten");
                              },
                            ),
                            TextButton(
                              child: const Text('7,42 h'),
                              onPressed: () {
                                showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.now(),
                                    cancelText: "Abbrechen",
                                    helpText: "Arbeits Stunden",
                                    hourLabelText: "Stunden",
                                    minuteLabelText: "Minuten");
                              },
                            ),
                            TextButton(
                              child: const Text('17:30 Uhr'),
                              onPressed: () {
                                showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.now(),
                                    cancelText: "Abbrechen",
                                    helpText: "End Zeit",
                                    hourLabelText: "Stunden",
                                    minuteLabelText: "Minuten");
                              },
                            ),
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
