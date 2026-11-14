import 'package:flutter/material.dart';

import '../../domain/utils/work_locations.dart';
import '../../l10n/app_localizations.dart';
import 'common/sheet_insets.dart';
import 'work_locations_input.dart';

/// Öffnet das Bottom Sheet „Arbeitsorte“ (#526, Dashboard-Button bzw.
/// Orte-Zeile). Liefert die bereinigte Liste (leer = alle Orte entfernen) oder
/// `null` bei Abbrechen/Wegwischen.
Future<List<String>?> showWorkLocationsSheet(
  BuildContext context, {
  required List<String> locations,
  required WorkLocationSuggestions suggestions,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => WorkLocationsSheet(
      initialLocations: locations,
      suggestions: suggestions,
    ),
  );
}

/// Inhalt des Bottom Sheets „Arbeitsorte“ (Pendant zum Web
/// `WorkLocationsDialogComponent`): Orte hinzufügen und entfernen, speichern
/// oder ohne Änderung abbrechen. Beim Speichern wird noch getippter Text
/// übernommen; ist er ungültig, bleibt das Sheet offen und erklärt es.
///
/// Edge-to-Edge (#468): unten [bottomSheetBottomInset] (Tastatur oder
/// Navigationsleiste), der Inhalt scrollt bei kleinem Bildschirm.
class WorkLocationsSheet extends StatefulWidget {
  const WorkLocationsSheet({
    super.key,
    required this.initialLocations,
    required this.suggestions,
  });

  final List<String> initialLocations;
  final WorkLocationSuggestions suggestions;

  @override
  State<WorkLocationsSheet> createState() => _WorkLocationsSheetState();
}

class _WorkLocationsSheetState extends State<WorkLocationsSheet> {
  final _inputKey = GlobalKey<WorkLocationsInputState>();
  late List<String> _locations =
      normalizeWorkLocations(widget.initialLocations);

  void _save() {
    if (!(_inputKey.currentState?.commitPending() ?? true)) return;
    Navigator.of(context).pop(normalizeWorkLocations(_locations));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: bottomSheetBottomInset(context)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(l10n.workLocationSheetTitle,
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            const SizedBox(height: 16),
            WorkLocationsInput(
              key: _inputKey,
              locations: _locations,
              onChanged: (value) => setState(() => _locations = value),
              suggestions: widget.suggestions,
            ),
            const SizedBox(height: 16),
            OverflowBar(
              alignment: MainAxisAlignment.end,
              spacing: 8,
              overflowAlignment: OverflowBarAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: _save,
                  child: Text(l10n.save),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
