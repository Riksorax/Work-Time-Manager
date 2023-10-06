import 'package:flutter/material.dart';

class ManuelSelection extends StatefulWidget {
  final TimeOfDay? workTime;
  final TimeOfDay? breakTime;

  const ManuelSelection({Key? key, this.workTime, this.breakTime}) : super(key: key);

  @override
  State<ManuelSelection> createState() => _ManuelSelectionState();
}

class _ManuelSelectionState extends State<ManuelSelection> {
  @override
  Widget build(BuildContext context) {

    TimeOfDay? workTime = widget.workTime;
    TimeOfDay? breakTime = widget.breakTime;
    TimeOfDay? workTimeBegin;
    TimeOfDay workTimeEnd;
    var test;

    return Container(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Container(
            child: Column(
              children: [
                Container(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        child: const Text('Arbeitsbeginn'),
                      ),
                    ],
                  ),
                ),
                Container(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.only(top: 10),
                        child: OutlinedButton(
                          onPressed: () {
                            showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.now(),
                              helpText: 'Arbeitsbeginn',
                            ).then((value) {
                              setState(() {
                                workTimeBegin = value!;
                              });
                            });
                          },
                          child: Row(
                            children: [
                              Container(
                                margin: const EdgeInsets.only(right: 4),
                                child: Text(
                                  workTimeBegin != null ? workTimeBegin.format(context) : '00:00',
                                ),
                              ),
                              Container(child: const Icon(Icons.access_alarm)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
          Container(
            child: Column(
              children: [
                Container(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        child: const Text('Arbeitsende'),
                      ),
                    ],
                  ),
                ),
                Container(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.only(top: 10),
                        child: OutlinedButton(
                            onPressed: () {

                            },
                            child: Row(
                              children: [
                                Container(margin: const EdgeInsets.only(right: 4) ,child: const Text(test.toString();)),
                                Container(child: const Icon(Icons.access_alarm)),
                              ],
                            )),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
          Container(
            child: Column(
              children: [
                Container(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        child: const Text('Arbeitzeit'),
                      ),
                    ],
                  ),
                ),
                Container(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.only(top: 10),
                        child: OutlinedButton(
                            onPressed: () {
                              showTimePicker(
                                context: context, initialTime: workTime == null ? TimeOfDay(hour: 07, minute: 42) : workTime!, helpText: 'Arbeitzeit',
                              ).then((value) {
                                setState(() {
                                  if(value == null){
                                    return;
                                  }
                                  workTime = value;
                                });
                              });
                            },
                            child: Row(
                              children: [
                                Container(margin: const EdgeInsets.only(right: 4) ,child: Text(workTime == null ? '07:42' : workTime.format(context))),
                                Container(child: const Icon(Icons.access_alarm)),
                              ],
                            )),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
          Container(
            child: Column(
              children: [
                Container(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        child: const Text('Pause'),
                      ),
                    ],
                  ),
                ),
                Container(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.only(top: 10),
                        child: OutlinedButton(
                            onPressed: () {
                              showTimePicker(
                                context: context, initialTime: breakTime == null ? TimeOfDay(hour: 00, minute: 30) : breakTime!, helpText: 'Pause',
                              ).then((value) {
                                setState(() {
                                  if(value == null){
                                    return;
                                  }
                                  breakTime = value;
                                });
                              });
                            },
                            child: Row(
                              children: [
                                Container(margin: const EdgeInsets.only(right: 4) ,child: Text(breakTime == null ? '00:30' : breakTime.format(context))),
                                Container(child: const Icon(Icons.access_alarm)),
                              ],
                            )),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
