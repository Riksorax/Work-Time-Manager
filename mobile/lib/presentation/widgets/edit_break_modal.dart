import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/time_format.dart';
import '../../domain/entities/break_entity.dart';
import '../../l10n/app_localizations.dart';
import '../view_models/dashboard_view_model.dart';
import '../view_models/settings_view_model.dart';

class EditBreakModal extends ConsumerStatefulWidget {
  final BreakEntity breakEntity;

  const EditBreakModal({super.key, required this.breakEntity});

  @override
  ConsumerState<EditBreakModal> createState() => _EditBreakModalState();
}

class _EditBreakModalState extends ConsumerState<EditBreakModal> {
  late TextEditingController _nameController;
  late TextEditingController _startController;
  late TextEditingController _endController;
  late DateTime _startTime;
  late DateTime? _endTime;
  late bool _use24HourFormat;

  @override
  void initState() {
    super.initState();
    _use24HourFormat =
        ref.read(settingsViewModelProvider).value?.settings.use24HourFormat ?? true;
    _nameController = TextEditingController(text: widget.breakEntity.name);
    _startTime = widget.breakEntity.start;
    _endTime = widget.breakEntity.end;
    _startController = TextEditingController(
        text: formatTime(_startTime, use24HourFormat: _use24HourFormat));
    _endController = TextEditingController(
        text: _endTime != null
            ? formatTime(_endTime!, use24HourFormat: _use24HourFormat)
            : '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    final initialTime =
        TimeOfDay.fromDateTime(isStartTime ? _startTime : _endTime ?? _startTime);
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (selectedTime != null) {
      final now = DateTime.now();
      final newDateTime = DateTime(
          now.year, now.month, now.day, selectedTime.hour, selectedTime.minute);
      setState(() {
        if (isStartTime) {
          // Berechne die bisherige Dauer, um die Endzeit mitzuverschieben
          final Duration? previousDuration = _endTime?.difference(_startTime);
          _startTime = newDateTime;
          _startController.text = formatTime(_startTime, use24HourFormat: _use24HourFormat);

          // Verschiebe die Endzeit, um die Dauer beizubehalten
          if (previousDuration != null) {
            _endTime = _startTime.add(previousDuration);
            _endController.text = formatTime(_endTime!, use24HourFormat: _use24HourFormat);
          }
        } else {
          _endTime = newDateTime;
          _endController.text = formatTime(_endTime!, use24HourFormat: _use24HourFormat);
        }
      });
    }
  }

  void _saveChanges() {
    if (_endTime != null && _endTime!.isBefore(_startTime)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context).endBeforeStartError),
        backgroundColor: Colors.red,
      ));
      return;
    }

    final updatedBreak = widget.breakEntity.copyWith(
      name: _nameController.text,
      start: _startTime,
      end: _endTime,
    );

    ref.read(dashboardViewModelProvider.notifier).updateBreak(updatedBreak);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.editBreakTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: l10n.breakNameLabel,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _startController,
            decoration: InputDecoration(
              labelText: l10n.startTimeLabel,
              suffixIcon: const Icon(Icons.access_time),
            ),
            readOnly: true,
            onTap: () => _selectTime(context, true),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _endController,
            decoration: InputDecoration(
              labelText: l10n.endTimeLabel,
              suffixIcon: const Icon(Icons.access_time),
            ),
            readOnly: true,
            onTap: () => _selectTime(context, false),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: _saveChanges,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
