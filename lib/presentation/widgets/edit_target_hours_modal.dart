import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../view_models/settings_view_model.dart';

void showEditTargetHoursModal(BuildContext context, double currentHours) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: EditTargetHoursModal(currentHours: currentHours),
    ),
  );
}

class EditTargetHoursModal extends ConsumerStatefulWidget {
  final double currentHours;

  const EditTargetHoursModal({super.key, required this.currentHours});

  @override
  ConsumerState<EditTargetHoursModal> createState() =>
      _EditTargetHoursModalState();
}

class _EditTargetHoursModalState extends ConsumerState<EditTargetHoursModal> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();
  bool _isAdjusting = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentHours.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      final hours = double.tryParse(_controller.text.replaceAll(',', '.'));
      if (hours != null) {
        // Hier den alten Wert speichern, bevor er geändert wird
        final oldHours = widget.currentHours;

        // Arbeitsstunden setzen
        await ref
            .read(settingsViewModelProvider.notifier)
            .setTargetWeeklyHours(hours);

        // Dialog anzeigen, ob alle vorhandenen Einträge angepasst werden sollen
        if (mounted && oldHours != hours) {
          final shouldAdjust = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Vorhandene Einträge anpassen?'),
              content: const Text('Möchten Sie alle vorhandenen Arbeitszeiten proportional zur neuen Soll-Arbeitszeit anpassen?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Nein'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Ja'),
                ),
              ],
            ),
          ) ?? false;

          if (shouldAdjust) {
            // Status auf "Anpassung läuft" setzen und UI aktualisieren
            setState(() {
              _isAdjusting = true;
            });

            try {
              // Anpassungsfaktor berechnen
              final adjustmentFactor = hours / oldHours;

              // WorkRepository aufrufen, um alle Einträge anzupassen
              await ref.read(settingsViewModelProvider.notifier)
                  .adjustAllWorkEntries(adjustmentFactor);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Alle Arbeitszeiten wurden angepasst')),
                );
              }
            } finally {
              // Status zurücksetzen, falls wir noch angezeigt werden
              if (mounted) {
                setState(() {
                  _isAdjusting = false;
                });
              }
            }
          }
        }

        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Soll-Arbeitsstunden bearbeiten',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (_isAdjusting) 
                  const SizedBox(
                    width: 24, 
                    height: 24, 
                    child: CircularProgressIndicator(strokeWidth: 2.0),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Wöchentliche Soll-Stunden',
                border: const OutlineInputBorder(),
                // Visuelles Feedback, dass das Feld gesperrt ist
                filled: _isAdjusting,
                fillColor: _isAdjusting ? Colors.grey.shade200 : null,
              ),
              enabled: !_isAdjusting, // Feld sperren während der Anpassung
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Bitte geben Sie eine Zahl ein.';
                }
                final number = double.tryParse(value.replaceAll(',', '.'));
                if (number == null) {
                  return 'Ungültige Zahl.';
                }
                if (number <= 0 || number > 100) {
                  return 'Bitte geben Sie einen Wert zwischen 1 und 100 ein.';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isAdjusting ? null : () => Navigator.of(context).pop(),
                  child: const Text('Abbrechen'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isAdjusting ? null : _save,
                  child: _isAdjusting
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16, 
                              height: 16, 
                              child: CircularProgressIndicator(strokeWidth: 2.0, color: Colors.white),
                            ),
                            SizedBox(width: 8),
                            Text('Wird angepasst...'),
                          ],
                        )
                      : const Text('Speichern'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
