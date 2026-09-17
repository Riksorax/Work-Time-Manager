import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/work_entry_entity.dart';
import '../../l10n/app_localizations.dart';

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

  String _getWorkEntryTypeLabel(AppLocalizations l10n, WorkEntryType type) {
    switch (type) {
      case WorkEntryType.vacation:
        return l10n.workEntryTypeVacation;
      case WorkEntryType.sick:
        return l10n.workEntryTypeSick;
      case WorkEntryType.holiday:
        return l10n.workEntryTypeHoliday;
      case WorkEntryType.work:
        return l10n.workEntryTypeWork;
    }
  }

  String _formatDateRange(BuildContext context) {
    if (widget.dates.isEmpty) return '';

    final sortedDates = List<DateTime>.from(widget.dates)..sort();
    final firstDate = sortedDates.first;
    final lastDate = sortedDates.last;

    final formatter = DateFormat.yMMMMd(Localizations.localeOf(context).toString());
    if (firstDate.year == lastDate.year &&
        firstDate.month == lastDate.month &&
        firstDate.day == lastDate.day) {
      return formatter.format(firstDate);
    }

    return '${formatter.format(firstDate)} - ${formatter.format(lastDate)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.quickEntryTitleBatch(widget.dates.length)),
          const SizedBox(height: 4),
          Text(
            _formatDateRange(context),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<WorkEntryType>(
            initialValue: _selectedType,
            decoration: InputDecoration(labelText: l10n.typeLabel),
            items: [
              WorkEntryType.vacation,
              WorkEntryType.sick,
              WorkEntryType.holiday,
            ].map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(_getWorkEntryTypeLabel(l10n, type)),
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
          child: Text(l10n.cancel),
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
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

