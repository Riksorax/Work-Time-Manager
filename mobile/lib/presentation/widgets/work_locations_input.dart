import 'package:flutter/material.dart';

import '../../domain/utils/work_locations.dart';
import '../../l10n/app_localizations.dart';

/// Liefert Vorschläge für die Orte-Eingabe: ohne [selected], gefiltert auf
/// [filter] (zuletzt verwendete zuerst, siehe `WorkLocationHistory`).
typedef WorkLocationSuggestions = List<String> Function(
    List<String> selected, String filter);

/// Eingabe der Arbeitsorte eines Tages (#526): Chips mit Entfernen und ein
/// Textfeld mit Vorschlägen ([RawAutocomplete]). Pendant zur Web-Komponente
/// `WorkLocationsInputComponent`.
///
/// - Hinzufügen mit Enter oder Komma, per Vorschlag oder über
///   [WorkLocationsInputState.commitPending] (z. B. beim Speichern).
/// - Leere, doppelte (Groß-/Kleinschreibung egal) und zu lange Eingaben werden
///   nicht übernommen und erklärt; bei 5 Orten ist das Feld gesperrt und sagt
///   warum.
/// - Die Vorschlagsliste ist beim Öffnen zu und erscheint erst beim Tippen
///   oder Antippen des Felds; nach dem Hinzufügen und bei einem Tipp außerhalb
///   schließt sie wieder (sie soll die Buttons eines Sheets nicht dauerhaft
///   verdecken).
class WorkLocationsInput extends StatefulWidget {
  const WorkLocationsInput({
    super.key,
    required this.locations,
    required this.onChanged,
    required this.suggestions,
  });

  /// Aktuell gewählte Orte (bereinigt).
  final List<String> locations;

  /// Neue Liste nach Hinzufügen oder Entfernen.
  final ValueChanged<List<String>> onChanged;

  final WorkLocationSuggestions suggestions;

  @override
  State<WorkLocationsInput> createState() => WorkLocationsInputState();
}

class WorkLocationsInputState extends State<WorkLocationsInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  AddWorkLocationError? _error;

  /// Vorschlagsliste freigegeben (Tippen/Antippen); siehe Klassendoku.
  bool _revealed = false;

  bool get _atMax => widget.locations.length >= maxWorkLocations;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Übernimmt noch getippten Text. `false`, wenn er ungültig ist (der Fehler
  /// wird angezeigt), sonst `true` (auch bei leerem Feld).
  bool commitPending() {
    if (_controller.text.trim().isEmpty) return true;
    return _add(_controller.text);
  }

  bool _add(String raw) {
    final result = addWorkLocation(widget.locations, raw);
    if (result.error != null) {
      setState(() => _error = result.error);
      return false;
    }
    setState(() {
      _error = null;
      _revealed = false;
    });
    _controller.clear();
    widget.onChanged(result.locations);
    return true;
  }

  void _remove(String location) {
    setState(() => _error = null);
    widget.onChanged(
        widget.locations.where((l) => l != location).toList(growable: false));
  }

  void _onTextChanged(String value) {
    // Komma wirkt wie Enter: alles davor übernehmen, den Rest stehen lassen.
    if (value.contains(',')) {
      final index = value.lastIndexOf(',');
      final before = value.substring(0, index);
      final rest = value.substring(index + 1);
      var ok = true;
      var current = widget.locations;
      for (final part in before.split(',')) {
        if (part.trim().isEmpty) continue;
        final result = addWorkLocation(current, part);
        if (result.error != null) {
          setState(() => _error = result.error);
          ok = false;
          break;
        }
        current = result.locations;
      }
      if (current.length != widget.locations.length) {
        widget.onChanged(current);
      }
      final keep = ok ? rest : value.replaceAll(',', '');
      _controller.value = TextEditingValue(
        text: keep,
        selection: TextSelection.collapsed(offset: keep.length),
      );
      if (ok) {
        setState(() {
          _error = null;
          _revealed = false;
        });
      }
      return;
    }
    setState(() {
      _revealed = true;
      if (_error != null && _error != AddWorkLocationError.max) _error = null;
    });
  }

  String? _errorText(AppLocalizations l10n) => switch (_error) {
        null => null,
        AddWorkLocationError.empty => l10n.workLocationErrorEmpty,
        AddWorkLocationError.duplicate => l10n.workLocationErrorDuplicate,
        AddWorkLocationError.tooLong =>
          l10n.workLocationErrorTooLong(maxWorkLocationLength),
        AddWorkLocationError.max => l10n.workLocationErrorMax(maxWorkLocations),
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final atMax = _atMax;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.locations.isNotEmpty) ...[
          Semantics(
            container: true,
            label: l10n.workLocationChipsLabel,
            child: Wrap(
              spacing: 8,
              runSpacing: 0,
              children: [
                for (final loc in widget.locations)
                  InputChip(
                    avatar: const Icon(Icons.place_outlined, size: 18),
                    label: Text(loc, overflow: TextOverflow.ellipsis),
                    onDeleted: () => _remove(loc),
                    deleteButtonTooltipMessage: l10n.workLocationRemove(loc),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        RawAutocomplete<String>(
          textEditingController: _controller,
          focusNode: _focusNode,
          optionsBuilder: (value) => atMax
              ? const <String>[]
              : widget.suggestions(widget.locations, value.text),
          onSelected: (option) => _add(option),
          // Die Liste öffnet nach oben, direkt über dem Feld: so verdeckt sie
          // nie die Buttons unter dem Feld (Sheet, Dialog) und bleibt auch
          // bei eingeblendeter Tastatur sichtbar. Sie überdeckt nur
          // vorübergehend Titel und Chips, bis ein Ort gewählt ist.
          optionsViewOpenDirection: OptionsViewOpenDirection.up,
          fieldViewBuilder: (context, controller, focusNode, _) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: !atMax,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.sentences,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: l10n.workLocationInputLabel,
                prefixIcon: const Icon(Icons.add_location_alt_outlined),
                border: const OutlineInputBorder(),
                helperText: atMax
                    ? l10n.workLocationMaxReached(maxWorkLocations)
                    : l10n.workLocationHint(
                        maxWorkLocations, maxWorkLocationLength),
                helperMaxLines: 3,
                // Auch bei gesperrtem Feld (5 Orte) gut lesbar.
                helperStyle: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                errorText: _errorText(l10n),
                errorMaxLines: 3,
              ),
              onTap: () {
                if (!_revealed) setState(() => _revealed = true);
              },
              onTapOutside: (_) {
                if (_revealed) setState(() => _revealed = false);
              },
              onChanged: _onTextChanged,
              // Enter übernimmt den getippten Text; Fokus und Tastatur
              // bleiben für den nächsten Ort.
              onEditingComplete: () {},
              onSubmitted: (value) {
                if (value.trim().isEmpty) {
                  setState(() => _error = null);
                  return;
                }
                _add(value);
                focusNode.requestFocus();
              },
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            if (!_revealed || options.isEmpty) return const SizedBox.shrink();
            return Align(
              alignment: AlignmentDirectional.bottomStart,
              // Abstand, damit die Beschriftung des Felds sichtbar bleibt.
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Semantics(
                  container: true,
                  label: l10n.workLocationSuggestionsLabel,
                  child: Material(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: theme.colorScheme.outlineVariant),
                    ),
                    clipBehavior: Clip.antiAlias,
                    color: theme.colorScheme.surfaceContainerHigh,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 4 * 48.0),
                      child: ListView(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        children: [
                          for (final option in options)
                            Semantics(
                              button: true,
                              label:
                                  l10n.workLocationSuggestionSemantics(option),
                              excludeSemantics: true,
                              child: InkWell(
                                onTap: () => onSelected(option),
                                child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(minHeight: 48),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    child: Row(
                                      children: [
                                        Icon(Icons.history,
                                            size: 18,
                                            color: theme
                                                .colorScheme.onSurfaceVariant),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(option,
                                              overflow: TextOverflow.ellipsis),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
