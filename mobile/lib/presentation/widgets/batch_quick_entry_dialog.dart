import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/work_entry_entity.dart';

class BatchQuickEntryDialog extends StatefulWidget {
  final List<DateTime> dates;
  final Duration? dailyTarget;

  const BatchQuickEntryDialog({
    super.key,
    required this.dates,
    this.dailyTarget,
  });

  @override
  State<BatchQuickEntryDialog> createState() => _BatchQuickEntryDialogState();
}

class _BatchQuickEntryDialogState extends State<BatchQuickEntryDialog> {
  WorkEntryType _selectedType = WorkEntryType.vacation;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  @override
  void initState() {
    super.initState();
    _setTimesBasedOnTarget();
  }

  void _setTimesBasedOnTarget() {
    setState(() {
      _startTime = const TimeOfDay(hour: 8, minute: 0);
      if (widget.dailyTarget != null) {
        final startDateTime = DateTime(2000, 1, 1, 8, 0);
        final endDateTime = startDateTime.add(widget.dailyTarget!);
        _endTime = TimeOfDay.fromDateTime(endDateTime);
      } else {
        _endTime = const TimeOfDay(hour: 16, minute: 0);
      }
    });
  }

  String _getWorkEntryTypeLabel(WorkEntryType type) {
    switch (type) {
      case WorkEntryType.vacation:
        return '🏖️ Urlaub';
      case WorkEntryType.sick:
        return '🤒 Krankheit';
      case WorkEntryType.holiday:
        return '📅 Feiertag';
      case WorkEntryType.work:
        return '💼 Arbeit';
    }
  }

  String _formatDateRange() {
    if (widget.dates.isEmpty) return '';

    final sortedDates = List<DateTime>.from(widget.dates)..sort();
    final firstDate = sortedDates.first;
    final lastDate = sortedDates.last;

    final formatter = DateFormat.yMMMMd('de_DE');
    if (firstDate.year == lastDate.year &&
        firstDate.month == lastDate.month &&
        firstDate.day == lastDate.day) {
      return formatter.format(firstDate);
    }

    return '${formatter.format(firstDate)} - ${formatter.format(lastDate)}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Schnell-Eintrag für ${widget.dates.length} Tage'),
          const SizedBox(height: 4),
          Text(
            _formatDateRange(),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<WorkEntryType>(
            initialValue: _selectedType,
            decoration: const InputDecoration(labelText: 'Typ'),
            items: [
              WorkEntryType.vacation,
              WorkEntryType.sick,
              WorkEntryType.holiday,
            ].map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(_getWorkEntryTypeLabel(type)),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedType = value;
                });
                _setTimesBasedOnTarget();
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () {
            // Return the selected type and times
            Navigator.pop(context, {
              'type': _selectedType,
              'startTime': _startTime,
              'endTime': _endTime,
            });
          },
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}

