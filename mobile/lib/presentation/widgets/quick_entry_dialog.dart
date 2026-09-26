import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/work_entry_entity.dart';
import '../../l10n/app_localizations.dart';

class QuickEntryDialog extends StatefulWidget {
  final DateTime date;
  final Duration? dailyTarget;

  const QuickEntryDialog({super.key, required this.date, this.dailyTarget});

  @override
  State<QuickEntryDialog> createState() => _QuickEntryDialogState();
}

class _QuickEntryDialogState extends State<QuickEntryDialog> {
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.quickEntryTitle),
          const SizedBox(height: 4),
          Text(
            DateFormat.yMMMMd(Localizations.localeOf(context).toString()).format(widget.date),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<WorkEntryType>(
            value: _selectedType,
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
             // Create the entry
             final entry = WorkEntryEntity(
               id: DateFormat('yyyy-MM-dd').format(widget.date),
               date: widget.date,
               type: _selectedType,
               isManuallyEntered: true,
               workStart: _startTime != null 
                   ? DateTime(widget.date.year, widget.date.month, widget.date.day, _startTime!.hour, _startTime!.minute)
                   : null,
               workEnd: _endTime != null
                   ? DateTime(widget.date.year, widget.date.month, widget.date.day, _endTime!.hour, _endTime!.minute)
                   : null,
             );
             Navigator.pop(context, entry);
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
