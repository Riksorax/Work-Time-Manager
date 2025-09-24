import 'package:flutter/material.dart';

class TotalOvertimeDisplay extends StatelessWidget {
  final Duration totalOvertime;
  final String title;

  const TotalOvertimeDisplay({
    required this.totalOvertime,
    this.title = 'Gesamtüberstunden',
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isNegative = totalOvertime.isNegative;
    final absDuration = totalOvertime.abs();

    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(absDuration.inHours);
    final minutes = twoDigits(absDuration.inMinutes.remainder(60));
    final sign = isNegative ? '-' : '+';
    final formattedOvertime = '$sign$hours:$minutes';

    return Column(
      children: [
        Text(
          isNegative 
            ? 'Gesamt-Minusstunden' 
            : 'Gesamt-Überstunden',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          formattedOvertime,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: isNegative ? Colors.red : Colors.green,
              ),
        ),
      ],
    );
  }
}
