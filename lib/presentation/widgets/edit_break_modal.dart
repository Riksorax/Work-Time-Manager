import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/break_entity.dart';
import '../view_models/dashboard_view_model.dart';

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

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.breakEntity.name);
    _startTime = widget.breakEntity.start;
    _endTime = widget.breakEntity.end;
    _startController =
        TextEditingController(text: DateFormat.Hm().format(_startTime));
    _endController = TextEditingController(
        text: _endTime != null ? DateFormat.Hm().format(_endTime!) : '');
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
          _startTime = newDateTime;
          _startController.text = DateFormat.Hm().format(_startTime);
        } else {
          _endTime = newDateTime;
          _endController.text = DateFormat.Hm().format(_endTime!);
        }
      });
    }
  }

  void _saveChanges() {
    if (_endTime != null && _endTime!.isBefore(_startTime)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Endzeit kann nicht vor der Startzeit liegen.'),
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
    return AlertDialog(
      title: const Text('Pause bearbeiten'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Pausenname',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _startController,
            decoration: const InputDecoration(
              labelText: 'Startzeit',
              suffixIcon: Icon(Icons.access_time),
            ),
            readOnly: true,
            onTap: () => _selectTime(context, true),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _endController,
            decoration: const InputDecoration(
              labelText: 'Endzeit',
              suffixIcon: Icon(Icons.access_time),
            ),
            readOnly: true,
            onTap: () => _selectTime(context, false),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          onPressed: _saveChanges,
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}
