import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/providers.dart';
import '../../../domain/entities/work_entry_entity.dart';
import '../../../domain/entities/work_entry_extensions.dart';

class TimeSummaryCard extends ConsumerWidget {
  final WorkEntryEntity workEntry;

  const TimeSummaryCard({
    super.key,
    required this.workEntry,
  });

  // Helper zum Formatieren einer Duration
  String _formatDuration(Duration duration) {
    if (duration.inSeconds < 0) return "00h 00m";
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    return '${hours}h ${minutes}m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsRepository = ref.watch(settingsRepositoryProvider);
    final workdaysPerWeek = settingsRepository.getWorkdaysPerWeek();
    final targetDailyHours = Duration(
      microseconds: (settingsRepository.getTargetWeeklyHours() / workdaysPerWeek * Duration.microsecondsPerHour).round(),
    );

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tagesübersicht',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            _SummaryTile(
              label: 'Gearbeitet (brutto)',
              value: _formatDuration(workEntry.calculatedWorkDuration),
            ),
            _SummaryTile(
              label: 'Pausenzeit',
              value: _formatDuration(workEntry.totalBreakDuration),
            ),
            const Divider(),
            _SummaryTile(
              label: 'Arbeitszeit (netto)',
              value: _formatDuration(workEntry.effectiveWorkDuration),
              isTotal: true,
            ),
            _SummaryTile(
              label: 'Überstunden',
              value: _formatDuration(workEntry.calculateOvertime(targetDailyHours)),
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;

  const _SummaryTile({
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = isTotal
        ? Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.bold,
    )
        : Theme.of(context).textTheme.bodyLarge;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}