import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/time_format.dart';
import '../../domain/entities/break_entity.dart';
import '../../domain/utils/date_utils.dart';
import '../../l10n/app_localizations.dart';
import '../utils/break_name_localizer.dart';
import '../view_models/dashboard_view_model.dart';
import '../view_models/settings_view_model.dart';
import 'common/dashboard_save_feedback.dart';

class EditBreakModal extends ConsumerStatefulWidget {
  final BreakEntity breakEntity;

  const EditBreakModal({super.key, required this.breakEntity});

  @override
  ConsumerState<EditBreakModal> createState() => _EditBreakModalState();
}

class _EditBreakModalState extends ConsumerState<EditBreakModal> {
  final _nameController = TextEditingController();
  late String _displayedOriginalName;
  bool _nameInitialized = false;
  late TextEditingController _startController;
  late TextEditingController _endController;
  late DateTime _startTime;
  late DateTime? _endTime;
  late bool _use24HourFormat;

  @override
  void initState() {
    super.initState();
    _use24HourFormat =
        ref.read(settingsViewModelProvider).value?.settings.use24HourFormat ??
            true;
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_nameInitialized) {
      // Standardnamen werden in der App-Sprache angezeigt (siehe #346); die
      // Lokalisierung braucht den BuildContext und kann nicht in initState.
      _displayedOriginalName = localizedBreakName(
          widget.breakEntity.name, AppLocalizations.of(context));
      _nameController.text = _displayedOriginalName;
      _nameInitialized = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    final initialTime = TimeOfDay.fromDateTime(
        isStartTime ? _startTime : _endTime ?? _startTime);
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (selectedTime != null) {
      // Basisdatum ist das Datum der Pause selbst, nicht "jetzt" (siehe #397):
      // Start nutzt den Tag des Starts, Ende den Tag des Endes (bzw. des Starts).
      final baseDay = isStartTime ? _startTime : _endTime ?? _startTime;
      final newDateTime =
          combineDateAndTime(baseDay, selectedTime.hour, selectedTime.minute);
      setState(() {
        if (isStartTime) {
          // Berechne die bisherige Dauer, um die Endzeit mitzuverschieben
          final Duration? previousDuration = _endTime?.difference(_startTime);
          _startTime = newDateTime;
          _startController.text =
              formatTime(_startTime, use24HourFormat: _use24HourFormat);

          // Verschiebe die Endzeit, um die Dauer beizubehalten
          if (previousDuration != null) {
            _endTime = _startTime.add(previousDuration);
            _endController.text =
                formatTime(_endTime!, use24HourFormat: _use24HourFormat);
          }
        } else {
          _endTime = newDateTime;
          _endController.text =
              formatTime(_endTime!, use24HourFormat: _use24HourFormat);
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

    // Unverändert gelassene Anzeige nicht als neuen Namen speichern, sonst
    // würde aus dem Standardnamen ein fest übersetzter Freitext (siehe #346).
    final name = _nameController.text == _displayedOriginalName
        ? widget.breakEntity.name
        : _nameController.text;

    final updatedBreak = widget.breakEntity.copyWith(
      name: name,
      start: _startTime,
      end: _endTime,
    );

    reportDashboardSave(
        context,
        ref
            .read(dashboardViewModelProvider.notifier)
            .updateBreak(updatedBreak));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Läuft eine Schreibaktion, würde ein Update verworfen und das Modal
    // trotzdem schließen: Speichern erst danach möglich (#413).
    final isSaving = ref.watch(dashboardViewModelProvider.select(
      (s) => s.isSaving,
    ));
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
          onPressed: isSaving ? null : _saveChanges,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
