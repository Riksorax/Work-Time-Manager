import 'package:flutter/material.dart';
import 'package:flutter_work_time/widget/manuelSelection.dart';
import 'package:flutter_work_time/widget/showCalculateTime.dart';

import 'widget/defaultSelection.dart';

void main() {
  runApp(const WorkTimeCalculate());
}

class WorkTimeCalculate extends StatelessWidget {
  const WorkTimeCalculate({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!),
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            bottom: const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.alarm), text: 'Arbeitszeiten'),
                Tab(
                  icon: Icon(Icons.list),
                  text: 'Zeiten Liste',
                ),
                Tab(icon: Icon(Icons.timer), text: 'Kommissionierzeit'),
              ],
            ),
          ),
          body: const TabBarView(
            children: <Widget>[
              SingleChildScrollView(
                child: DefaultSelection(),
              ),
              Row(
                children: [
                  //WorkTimeList(),
                ],
              ),
              Icon(Icons.directions_transit),
            ],
          ),
        ),
      ),
    );
  }
}
