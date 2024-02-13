import 'package:flutter/material.dart';
import 'package:flutter_work_time/theme.dart';

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
      debugShowCheckedModeBanner: false,
      theme: const MaterialTheme(TextTheme()).light(),
      darkTheme: const MaterialTheme(TextTheme()).dark(),
      themeMode: ThemeMode.dark,
      home: Scaffold(
        appBar: AppBar(
          leading: const IconButton(
            icon: Icon(Icons.menu),
            onPressed: null,
          ),
          centerTitle: true,
          title: const Text("Arbeitszeit Rechner"),
          actions: const [
            IconButton(
              onPressed: null,
              icon: Icon(Icons.person),
            ),
          ],
        ),
      ),
    );
  }
}
