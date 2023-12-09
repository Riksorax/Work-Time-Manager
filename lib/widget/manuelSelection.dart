import 'package:flutter/material.dart';

class ManuelSelection extends StatefulWidget {
  final TimeOfDay workTime;
  final TimeOfDay breakTime;

  const ManuelSelection({Key? key, required this.workTime, required this.breakTime}) : super(key: key);

  @override
  State<ManuelSelection> createState() => _ManuelSelectionState();
}

class _ManuelSelectionState extends State<ManuelSelection> {
  late TimeOfDay workTimeBegin;
  late TimeOfDay workTimeEnd;
  late TimeOfDay workTime;
  late TimeOfDay breakTime;

  @override
  void initState() {
    super.initState();
    workTimeBegin = const TimeOfDay(hour: 00, minute: 00);
    workTimeEnd = const TimeOfDay(hour: 00, minute: 00);
    workTime = widget.workTime;
    breakTime = widget.breakTime;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildColumn('Arbeitsbeginn', workTimeBegin, (value) {
          setState(() {
            if (value != null) {
              workTimeBegin = value;
            }
          });
        }),
        _buildColumn('Arbeitsende', workTimeEnd, (value) {
          setState(() {
            if (value != null) {
              workTimeEnd = value;
            }
          });
        }),
        _buildColumn('Arbeitzeit', widget.workTime, (value) {
          setState(() {
            if (value != null) {
              workTime = value;
            }
          });
        }),
        _buildColumn('Pause', widget.breakTime, (value) {
          setState(() {
            if (value != null) {
              breakTime = value;
            }
          });
        }),
        // ... Weitere Spalten hier einfügen
      ],
    );
  }

  Widget _buildColumn(String labelText, TimeOfDay timeOfDay, Function(TimeOfDay?) onPressed) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(labelText),
          ],
        ),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.only(top: 10),
              child: OutlinedButton(
                onPressed: () {
                  showTimePicker(
                    context: context,
                    initialTime: timeOfDay,
                    helpText: labelText,
                  ).then((value) {
                    onPressed(value);
                  });
                },
                child: Row(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 4),
                      child: Text(
                        timeOfDay.format(context),
                      ),
                    ),
                    const Icon(Icons.access_alarm),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
