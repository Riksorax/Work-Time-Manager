import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../view_models/settings_view_model.dart';

class AddAdjustmentModal extends ConsumerStatefulWidget {
  const AddAdjustmentModal({super.key});

  @override
  ConsumerState<AddAdjustmentModal> createState() =>
      _AddAdjustmentModalState();
}

class _AddAdjustmentModalState extends ConsumerState<AddAdjustmentModal> {
  final _hoursController = TextEditingController();
  final _minutesController = TextEditingController();
  bool _isNegative = false;

  @override
  void dispose() {
    _hoursController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  void _save() {
    // Überprüfen auf leere Eingaben
    if (_hoursController.text.isEmpty && _minutesController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte geben Sie mindestens Stunden oder Minuten ein')),
      );
      return;
    }

    // Stunden und Minuten als positive Werte parsen
    int parsedHours = int.tryParse(_hoursController.text) ?? 0;
    int parsedMinutes = int.tryParse(_minutesController.text) ?? 0;

    // Bei Minuten auf gültige Werte prüfen (0-59)
    if (parsedMinutes > 59) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minuten müssen zwischen 0 und 59 liegen')),
      );
      return;
    }

    // Mindestens einer der Werte muss größer als 0 sein
    if (parsedHours == 0 && parsedMinutes == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte geben Sie einen Wert größer als 0 ein')),
      );
      return;
    }

    // Erstelle die Dauer - Vorzeichen wird nur durch ChoiceChip bestimmt
    int totalMinutes = parsedHours * 60 + parsedMinutes;
    Duration duration = Duration(minutes: _isNegative ? -totalMinutes : totalMinutes);

    // Rufe die Methode im ViewModel auf
    ref.read(settingsViewModelProvider.notifier).setOvertimeBalance(ref, duration);

    // Modal schließen
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Überstunden / Minusstunden'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          const Text(
            'Manuelle Eingabe für den heutigen Tag. Wählen Sie zuerst Überstunden oder Minusstunden.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          // Auswahl zwischen Überstunden (+) und Minusstunden (-)
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('Überstunden (+)'),
                  selected: !_isNegative,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _isNegative = false;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Text('Minusstunden (-)'),
                  selected: _isNegative,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _isNegative = true;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _hoursController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Stunden',
              border: OutlineInputBorder(),
              helperText: 'Leer lassen für 0 Stunden',
            ),
            onChanged: (value) {
              // Nur positive Zahlen erlauben
              if (value.isNotEmpty) {
                final cleanedValue = value.replaceAll(RegExp(r'[^0-9]'), '');
                if (cleanedValue != value) {
                  _hoursController.text = cleanedValue;
                  _hoursController.selection = TextSelection.fromPosition(
                    TextPosition(offset: _hoursController.text.length),
                  );
                }
              }
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _minutesController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Minuten (0-59)',
              border: OutlineInputBorder(),
              helperText: 'Leer lassen für 0 Minuten',
            ),
            onChanged: (value) {
              // Nur positive Zahlen erlauben und auf 59 begrenzen
              if (value.isNotEmpty) {
                final cleanedValue = value.replaceAll(RegExp(r'[^0-9]'), '');
                int? minutes = int.tryParse(cleanedValue);
                if (minutes != null && minutes > 59) {
                  _minutesController.text = '59';
                  _minutesController.selection = TextSelection.fromPosition(
                    TextPosition(offset: _minutesController.text.length),
                  );
                } else if (cleanedValue != value) {
                  _minutesController.text = cleanedValue;
                  _minutesController.selection = TextSelection.fromPosition(
                    TextPosition(offset: _minutesController.text.length),
                  );
                }
              }
            },
          ),
        ],
      )),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}
