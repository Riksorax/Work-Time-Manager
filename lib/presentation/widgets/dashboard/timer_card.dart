import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/work_entry_entity.dart';
import '../../view_models/dashboard_view_model.dart';

class TimerCard extends ConsumerWidget {
  final WorkEntryEntity workEntry;

  const TimerCard({
    Key? key,
    required this.workEntry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeFormat = DateFormat('HH:mm:ss');
    final bool isTimerRunning = workEntry.workStart != null && workEntry.workEnd == null;
    final bool isWorkDone = workEntry.workStart != null && workEntry.workEnd != null;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Arbeitszeit',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _TimeDisplay(
                  label: 'Start',
                  time: workEntry.workStart != null
                      ? timeFormat.format(workEntry.workStart!)
                      : '--:--:--',
                ),
                _TimeDisplay(
                  label: 'Ende',
                  time: workEntry.workEnd != null
                      ? timeFormat.format(workEntry.workEnd!)
                      : '--:--:--',
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: Icon(
                isTimerRunning ? Icons.pause_circle_filled : Icons.play_circle_filled,
              ),
              label: Text(
                isTimerRunning ? 'Arbeit beenden' : 'Arbeit starten',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isTimerRunning ? Colors.orange.shade700 : Colors.green.shade600,
                foregroundColor: Colors.white,
                minimumSize: const Size(200, 48),
              ),
              // Der Button ist deaktiviert, wenn die Arbeit für heute bereits abgeschlossen ist.
              onPressed: isWorkDone
                  ? null
                  : () => ref.read(dashboardViewModelProvider.notifier).startOrStopTimer(),
            ),
          ],
        ),
      ),
    );
  }
}

// Ein kleines privates Helfer-Widget, um Code-Duplizierung zu vermeiden
class _TimeDisplay extends StatelessWidget {
  final String label;
  final String time;

  const _TimeDisplay({
    required this.label,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 4),
        Text(
          time,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}