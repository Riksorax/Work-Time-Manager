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

    // Stunden und Minuten als Werte parsen
    int parsedHours = int.tryParse(_hoursController.text.replaceFirst('-', '')) ?? 0;
    int parsedMinutes = int.tryParse(_minutesController.text.replaceFirst('-', '')) ?? 0;

    // Überprüfen ob die Eingabe negativ ist
    bool hoursNegative = _hoursController.text.startsWith('-');
    bool minutesNegative = _minutesController.text.startsWith('-');

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

    // Erstelle die Dauer unter Berücksichtigung separater negativer Werte
    int totalHoursMinutes = parsedHours * 60 + parsedMinutes;
    if (hoursNegative || minutesNegative) {
      // Wenn eines der Felder negativ ist, behandle beide als negativ
      totalHoursMinutes = -totalHoursMinutes;
    }

    // Wenn negativ ausgewählt wurde, erstelle eine negative Dauer
    Duration duration = Duration(minutes: totalHoursMinutes);
    if (_isNegative) {
      duration = -duration;
    }

    // Rufe die Methode im ViewModel auf
    ref.read(settingsViewModelProvider.notifier).setOvertimeBalance(duration);

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
            'Manuelle Eingabe für den heutigen Tag. Sie können auch negative Werte direkt eingeben.',
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
            keyboardType: TextInputType.numberWithOptions(signed: true),
            decoration: const InputDecoration(
              labelText: 'Stunden',
              border: OutlineInputBorder(),
              helperText: 'Leer lassen für 0 Stunden',
            ),
            onChanged: (value) {
              // Prüfen ob gültige Zahl
              if (value.isNotEmpty && double.tryParse(value) == null) {
                // Falls '-' allein steht, erlaube es
                if (value != '-') {
                  _hoursController.text = value.replaceAll(RegExp(r'[^0-9-]'), '');
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
            keyboardType: TextInputType.numberWithOptions(signed: true),
            decoration: const InputDecoration(
              labelText: 'Minuten (0-59)',
              border: OutlineInputBorder(),
              helperText: 'Leer lassen für 0 Minuten',
            ),
            onChanged: (value) {
              // Prüfen ob gültige Zahl
              if (value.isNotEmpty && double.tryParse(value) == null) {
                // Falls '-' allein steht, erlaube es
                if (value != '-') {
                  _minutesController.text = value.replaceAll(RegExp(r'[^0-9-]'), '');
                  _minutesController.selection = TextSelection.fromPosition(
                    TextPosition(offset: _minutesController.text.length),
                  );
                }
              } else if (value.isNotEmpty && value != '-') {
                // Begrenze den absoluten Wert auf 59
                String valueWithoutSign = value.startsWith('-') ? value.substring(1) : value;
                int? minutes = int.tryParse(valueWithoutSign);
                if (minutes != null && minutes > 59) {
                  _minutesController.text = value.startsWith('-') ? '-59' : '59';
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
