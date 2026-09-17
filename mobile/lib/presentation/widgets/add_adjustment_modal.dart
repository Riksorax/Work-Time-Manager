import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
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

  Future<void> _save() async {
    // Stunden und Minuten als positive Werte parsen
    int parsedHours = int.tryParse(_hoursController.text) ?? 0;
    int parsedMinutes = int.tryParse(_minutesController.text) ?? 0;

    // Bei Minuten auf gültige Werte prüfen (0-59)
    if (parsedMinutes > 59) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).minutesRangeError)),
      );
      return;
    }

    // Erstelle die Dauer - Vorzeichen wird nur durch ChoiceChip bestimmt
    int totalMinutes = parsedHours * 60 + parsedMinutes;
    Duration duration = Duration(minutes: _isNegative ? -totalMinutes : totalMinutes);

    // Rufe die Methode im ViewModel auf und warte den Abschluss ab, bevor das
    // Modal geschlossen wird - sonst bekäme das Dashboard die Änderung nicht
    // mehr mit (siehe #266).
    await ref.read(settingsViewModelProvider.notifier).setOvertimeBalance(duration);

    // Modal schließen
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _reset() async {
    // Setze die Gleitzeit-Bilanz auf 0 zurück
    await ref.read(settingsViewModelProvider.notifier).setOvertimeBalance(Duration.zero);

    // Modal schließen
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.adjustOvertimeTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          Text(
            l10n.adjustOvertimeDescription,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          // Auswahl zwischen Überstunden (+) und Minusstunden (-)
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: Text(l10n.overtimePositiveChip),
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
                  label: Text(l10n.overtimeNegativeChip),
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
            decoration: InputDecoration(
              labelText: l10n.hoursLabel,
              border: const OutlineInputBorder(),
              helperText: l10n.hoursHelperText,
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
            decoration: InputDecoration(
              labelText: l10n.minutesLabel,
              border: const OutlineInputBorder(),
              helperText: l10n.minutesHelperText,
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
          onPressed: _reset,
          child: Text(l10n.resetToZeroAction),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
