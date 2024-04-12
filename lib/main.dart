import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_work_time/features/presentation/work_time_screen.dart';
import 'package:flutter_work_time/features/shared/presentation/theme/theme.dart';

void main() {
  runApp(const ProviderScope(child: WorkTimeCalculate()));
}

class WorkTimeCalculate extends ConsumerWidget {
  const WorkTimeCalculate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        body: const SingleChildScrollView(
          child: WorkTimeScreen(),
        ),
      ),
    );
  }
}
