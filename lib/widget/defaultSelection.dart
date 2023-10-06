import 'package:flutter/material.dart';
import 'package:flutter_work_time/widget/manuelSelection.dart';

class DefaultSelection extends StatefulWidget {
  DefaultSelection({super.key});

  @override
  State<DefaultSelection> createState() => _DefaultSelectionState();
}

class _DefaultSelectionState extends State<DefaultSelection> {
  TimeOfDay? defaultWorkTimeBreak;
  TimeOfDay? defaultWorkTime;

  ButtonStyle selectedButtonStyle = TextButton.styleFrom(
    backgroundColor: Colors.grey, // Hintergrundfarbe beim Klicken
  );

  TextStyle selectedTextStyle = TextStyle(color: Colors.white); // Schriftfarbe beim Klicken

  Widget buildTimeButtonWorkTime(String timeText, TimeOfDay timeOfDay) {
    return Container(
      child: TextButton(
        onPressed: () {
          setState(() {
            defaultWorkTime = timeOfDay;
          });
        },
        child: Text(timeText, style: defaultWorkTime == timeOfDay ? selectedTextStyle : null),
        style: defaultWorkTime == timeOfDay ? selectedButtonStyle : null,
      ),
    );
  }

  Widget buildTimeButtonWorkTimeBreak(String timeText, TimeOfDay timeOfDay) {
    return Container(
      child: TextButton(
        onPressed: () {
          setState(() {
            defaultWorkTimeBreak = timeOfDay;
          });
        },
        child: Text(timeText, style: defaultWorkTimeBreak == timeOfDay ? selectedTextStyle : null),
        style: defaultWorkTimeBreak == timeOfDay ? selectedButtonStyle : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double deviceWidth = MediaQuery.of(context).size.width;
    print('deviceWidth: ${deviceWidth}');
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
                          '06:00', TimeOfDay(hour: 6, minute: 0)),
                      buildTimeButtonWorkTime(
                          '07:00', TimeOfDay(hour: 7, minute: 0)),
                      buildTimeButtonWorkTime(
                          '07:42', TimeOfDay(hour: 7, minute: 42)),
                      buildTimeButtonWorkTime(
                          '08:00', TimeOfDay(hour: 8, minute: 0)),
                    ]),
                    buildTimeSelectionColumn('Pausen Zeiten', [
                      buildTimeButtonWorkTimeBreak(
                          '00:00', TimeOfDay(hour: 0, minute: 0)),
                      buildTimeButtonWorkTimeBreak(
                          '00:30', TimeOfDay(hour: 0, minute: 30)),
                      buildTimeButtonWorkTimeBreak(
                          '00:45', TimeOfDay(hour: 0, minute: 45)),
                      buildTimeButtonWorkTimeBreak(
                          '01:00', TimeOfDay(hour: 1, minute: 0)),
                    ]),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    buildTimeSelectionColumn('Arbeitszeiten', [
                      buildTimeButtonWorkTime(
                          '06:00', TimeOfDay(hour: 6, minute: 0)),
                      buildTimeButtonWorkTime(
                          '07:00', TimeOfDay(hour: 7, minute: 0)),
                      buildTimeButtonWorkTime(
                          '07:42', TimeOfDay(hour: 7, minute: 42)),
                      buildTimeButtonWorkTime(
                          '08:00', TimeOfDay(hour: 8, minute: 0)),
                    ]),
                    Container(
                      margin: EdgeInsets.only(top: 10),
                      child: buildTimeSelectionColumn('Pausen Zeiten', [
                        buildTimeButtonWorkTimeBreak(
                            '00:00', TimeOfDay(hour: 0, minute: 0)),
                        buildTimeButtonWorkTimeBreak(
                            '00:30', TimeOfDay(hour: 0, minute: 30)),
                        buildTimeButtonWorkTimeBreak(
                            '00:45', TimeOfDay(hour: 0, minute: 45)),
                        buildTimeButtonWorkTimeBreak(
                            '01:00', TimeOfDay(hour: 1, minute: 0)),
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
    return Container(
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                child: Text(title),
              ),
            ],
          ),
          Container(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: timeButtons,
            ),
          ),
        ],
      ),
    );
  }
}
