import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/utils/time_format.dart';
import '../../domain/entities/work_entry_entity.dart';
import '../../domain/utils/entry_day.dart';
import '../../domain/utils/overtime_utils.dart';
import '../../l10n/app_localizations.dart';

/// Datumswahl des Dialogs (in Tests ersetzbar).
typedef OpenEntryDatePicker = Future<DateTime?> Function(
    BuildContext context, DateTime initial, DateTime first, DateTime last);

/// Zeitwahl des Dialogs (in Tests ersetzbar).
typedef OpenEntryTimePicker = Future<TimeOfDay?> Function(
    BuildContext context, TimeOfDay initial);

/// Ab dieser Netto-Dauer erscheint der weiche Hinweis "Stimmt das?".
const Duration openEntryLongWarningThreshold = Duration(hours: 16);

/// Fragt das Ende eines offenen Eintrags vor heute ab (#385). Gibt das
/// gewählte Ende zurück, `null` bei Abbruch.
Future<DateTime?> showOpenEntryEndDialog(
  BuildContext context, {
  required WorkEntryEntity entry,
  required DateTime now,
  required Duration dailyTarget,
  required bool use24HourFormat,
  OpenEntryDatePicker? pickDate,
  OpenEntryTimePicker? pickTime,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (context) => OpenEntryEndDialog(
      entry: entry,
      now: now,
      dailyTarget: dailyTarget,
      use24HourFormat: use24HourFormat,
      pickDate: pickDate,
      pickTime: pickTime,
    ),
  );
}

class OpenEntryEndDialog extends StatefulWidget {
  const OpenEntryEndDialog({
    super.key,
    required this.entry,
    required this.now,
    required this.dailyTarget,
    required this.use24HourFormat,
    this.pickDate,
    this.pickTime,
  });

  final WorkEntryEntity entry;
  final DateTime now;
  final Duration dailyTarget;
  final bool use24HourFormat;
  final OpenEntryDatePicker? pickDate;
  final OpenEntryTimePicker? pickTime;

  @override
  State<OpenEntryEndDialog> createState() => _OpenEntryEndDialogState();
}

class _OpenEntryEndDialogState extends State<OpenEntryEndDialog> {
  late final OpenEntryEndSuggestion _suggestion;
  late DateTime _date;
  TimeOfDay? _time;

  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime get _firstDate => _dayOf(widget.entry.workStart!);
  DateTime get _lastDate => _dayOf(widget.now);

  @override
  void initState() {
    super.initState();
    _suggestion = suggestOpenEntryEnd(
      entry: widget.entry,
      dailyTarget: widget.dailyTarget,
      now: widget.now,
    );
    final suggested = _suggestion.suggestedEnd;
    _date = _dayOf(suggested ?? widget.entry.workStart!);
    _time = suggested == null
        ? null
        : TimeOfDay(hour: suggested.hour, minute: suggested.minute);
  }

  DateTime? get _end {
    final time = _time;
    if (time == null) return null;
    return DateTime(_date.year, _date.month, _date.day, time.hour, time.minute);
  }

  bool get _invalid {
    final end = _end;
    return end != null &&
        !isValidOpenEntryEnd(entry: widget.entry, end: end, now: widget.now);
  }

  bool get _longWarning {
    final end = _end;
    if (end == null || _invalid) return false;
    final net =
        end.difference(widget.entry.workStart!) - widget.entry.totalBreakTime;
    return net > openEntryLongWarningThreshold;
  }

  void _apply(DateTime end) {
    setState(() {
      _date = _dayOf(end);
      _time = TimeOfDay(hour: end.hour, minute: end.minute);
    });
  }

  Future<void> _selectDate() async {
    final first = _firstDate;
    final last = _lastDate;
    final initial =
        _date.isBefore(first) ? first : (_date.isAfter(last) ? last : _date);
    final picker = widget.pickDate ??
        (context, initial, first, last) => showDatePicker(
              context: context,
              initialDate: initial,
              firstDate: first,
              lastDate: last,
            );
    final picked = await picker(context, initial, first, last);
    if (picked != null && mounted) setState(() => _date = _dayOf(picked));
  }

  Future<void> _selectTime() async {
    final initial = _time ?? const TimeOfDay(hour: 12, minute: 0);
    final picker = widget.pickTime ??
        (context, initial) => showTimePicker(
              context: context,
              initialTime: initial,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(alwaysUse24HourFormat: widget.use24HourFormat),
                child: child!,
              ),
            );
    final picked = await picker(context, initial);
    if (picked != null && mounted) setState(() => _time = picked);
  }

  String _formatClock(DateTime time) =>
      formatTime(time, use24HourFormat: widget.use24HourFormat);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final entryDate = DateFormat.MMMEd(locale).format(entryDay(widget.entry));
    final end = _end;
    final expectedEnd = _suggestion.expectedEnd;
    final showExpected = expectedEnd != null &&
        isValidOpenEntryEnd(
            entry: widget.entry, end: expectedEnd, now: widget.now);

    final timeText = _time == null
        ? l10n.openEntryEndPickTime
        : formatTime(
            DateTime(2000, 1, 1, _time!.hour, _time!.minute),
            use24HourFormat: widget.use24HourFormat,
          );

    return AlertDialog(
      title: Semantics(
        header: true,
        child: Text(l10n.openEntryEndDialogTitle),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.openEntryEndDialogBody(entryDate)),
            const SizedBox(height: 16),
            if (showExpected || _suggestion.nowAllowed)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (showExpected)
                    ActionChip(
                      label: Text(l10n.openEntryEndSuggestionExpected(
                          _formatClock(expectedEnd))),
                      onPressed: () => _apply(expectedEnd),
                    ),
                  if (_suggestion.nowAllowed)
                    ActionChip(
                      label: Text(l10n.openEntryEndSuggestionNow),
                      onPressed: () => _apply(widget.now),
                    ),
                ],
              ),
            if (showExpected || _suggestion.nowAllowed)
              const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PickerButton(
                  key: const Key('openEntryEndDate'),
                  icon: Icons.calendar_today_outlined,
                  label: l10n.openEntryEndDateLabel,
                  value: DateFormat.yMMMEd(locale).format(_date),
                  onPressed: _selectDate,
                ),
                _PickerButton(
                  key: const Key('openEntryEndTime'),
                  icon: Icons.schedule,
                  label: l10n.openEntryEndTimeLabel,
                  value: timeText,
                  onPressed: _selectTime,
                ),
              ],
            ),
            if (_invalid) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline, size: 20, color: scheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.openEntryEndInvalid,
                        style:
                            textTheme.bodyMedium?.copyWith(color: scheme.error),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_longWarning) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_outlined,
                        size: 20, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.openEntryEndLongWarning,
                        style: textTheme.bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: end == null || _invalid
              ? null
              : () => Navigator.of(context).pop(end),
          child: Text(l10n.openEntryEndDialogConfirm),
        ),
      ],
    );
  }
}

class _PickerButton extends StatelessWidget {
  const _PickerButton({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: textTheme.labelSmall),
              Text(value),
            ],
          ),
        ],
      ),
    );
  }
}
