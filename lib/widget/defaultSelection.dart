import 'package:flutter/material.dart';
import 'package:flutter_work_time/widget/manuelSelection.dart';

class DefaultSelection extends StatefulWidget {
  const DefaultSelection({super.key});

  @override
  State<DefaultSelection> createState() => _DefaultSelectionState();
}

class _DefaultSelectionState extends State<DefaultSelection> {
  late TimeOfDay defaultWorkTimeBreak = const TimeOfDay(hour: 00, minute: 30);
  late TimeOfDay defaultWorkTime = const TimeOfDay(hour: 07, minute: 42);

  ButtonStyle selectedButtonStyle = TextButton.styleFrom(
    backgroundColor: Colors.grey, // Hintergrundfarbe beim Klicken
  );

  TextStyle selectedTextStyle = const TextStyle(color: Colors.white); // Schriftfarbe beim Klicken

  Widget buildTimeButtonWorkTime(String timeText, TimeOfDay timeOfDay) {
    return TextButton(
      onPressed: () {
        setState(() {
          defaultWorkTime = timeOfDay;
        });
      },
      style: defaultWorkTime == timeOfDay ? selectedButtonStyle : null,
      child: Text(timeText, style: defaultWorkTime == timeOfDay ? selectedTextStyle : null),
    );
  }

  Widget buildTimeButtonWorkTimeBreak(String timeText, TimeOfDay timeOfDay) {
    return TextButton(
      onPressed: () {
        setState(() {
          defaultWorkTimeBreak = timeOfDay;
        });
      },
      style: defaultWorkTimeBreak == timeOfDay ? selectedButtonStyle : null,
      child: Text(timeText, style: defaultWorkTimeBreak == timeOfDay ? selectedTextStyle : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    double deviceWidth = MediaQuery.of(context).size.width;
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 10, bottom: 20),
          child: deviceWidth > 600
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    buildTimeSelectionColumn('Arbeitszeiten', [
                      buildTimeButtonWorkTime(
                          '06:00', const TimeOfDay(hour: 6, minute: 0)),
                      buildTimeButtonWorkTime(
                          '07:00', const TimeOfDay(hour: 7, minute: 0)),
                      buildTimeButtonWorkTime(
                          '07:42', const TimeOfDay(hour: 7, minute: 42)),
                      buildTimeButtonWorkTime(
                          '08:00', const TimeOfDay(hour: 8, minute: 0)),
                    ]),
                    buildTimeSelectionColumn('Pausen Zeiten', [
                      buildTimeButtonWorkTimeBreak(
                          '00:00', const TimeOfDay(hour: 0, minute: 0)),
                      buildTimeButtonWorkTimeBreak(
                          '00:30', const TimeOfDay(hour: 0, minute: 30)),
                      buildTimeButtonWorkTimeBreak(
                          '00:45', const TimeOfDay(hour: 0, minute: 45)),
                      buildTimeButtonWorkTimeBreak(
                          '01:00', const TimeOfDay(hour: 1, minute: 0)),
                    ]),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    buildTimeSelectionColumn('Arbeitszeiten', [
                      buildTimeButtonWorkTime(
                          '06:00', const TimeOfDay(hour: 6, minute: 0)),
                      buildTimeButtonWorkTime(
                          '07:00', const TimeOfDay(hour: 7, minute: 0)),
                      buildTimeButtonWorkTime(
                          '07:42', const TimeOfDay(hour: 7, minute: 42)),
                      buildTimeButtonWorkTime(
                          '08:00', const TimeOfDay(hour: 8, minute: 0)),
                    ]),
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      child: buildTimeSelectionColumn('Pausen Zeiten', [
                        buildTimeButtonWorkTimeBreak(
                            '00:00', const TimeOfDay(hour: 0, minute: 0)),
                        buildTimeButtonWorkTimeBreak(
                            '00:30', const TimeOfDay(hour: 0, minute: 30)),
                        buildTimeButtonWorkTimeBreak(
                            '00:45', const TimeOfDay(hour: 0, minute: 45)),
                        buildTimeButtonWorkTimeBreak(
                            '01:00', const TimeOfDay(hour: 1, minute: 0)),
                      ]),
                    ),
                  ],
                ),
        ),
        ManuelSelection(workTime: defaultWorkTime, breakTime: defaultWorkTimeBreak,)
      ],
    );
  }

  Widget buildTimeSelectionColumn(String title, List<Widget> timeButtons) {
    return Column(
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: timeButtons,
        ),
      ],
    );
  }
}
