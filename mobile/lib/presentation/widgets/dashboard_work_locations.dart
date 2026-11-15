import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Arbeitsorte im Dashboard (#526): ohne Orte der Button „Arbeitsort
/// hinzufügen“, mit Orten eine schlanke Zeile (Pin-Icon, Chips, Stift), die
/// bei wenig Platz umbricht und lange Orte kürzt. Beides öffnet über [onTap]
/// das Bottom Sheet „Arbeitsorte“. Reine Darstellung; ob es angezeigt wird
/// (Einstellung, Typ „Arbeit“), entscheidet der Aufrufer.
class DashboardWorkLocations extends StatelessWidget {
  const DashboardWorkLocations({
    super.key,
    required this.locations,
    required this.onTap,
  });

  final List<String> locations;

  /// `null` sperrt (z. B. während einer laufenden Schreibaktion).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final enabled = onTap != null;

    if (locations.isEmpty) {
      // Schlanker Text-Button in der Flucht von Pin-Zeile und
      // Home-Office-Schalter (Icon links, Text auf Höhe der Beschriftung).
      final color = enabled ? theme.colorScheme.primary : theme.disabledColor;
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: Semantics(
          button: true,
          enabled: enabled,
          label: l10n.workLocationAddButton,
          hint: l10n.workLocationAddSemantics,
          excludeSemantics: true,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_location_alt_outlined, color: color),
                    const SizedBox(width: 16),
                    Flexible(
                      child: Text(
                        l10n.workLocationAddButton,
                        style: theme.textTheme.labelLarge
                            ?.copyWith(color: color, fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final chipColor = theme.colorScheme.secondaryContainer;
    final onChip = theme.colorScheme.onSecondaryContainer;
    final iconColor =
        enabled ? theme.colorScheme.onSurfaceVariant : theme.disabledColor;

    return Semantics(
      button: true,
      enabled: enabled,
      label: l10n.workLocationEditSemantics(locations.join(', ')),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(Icons.place_outlined, color: iconColor),
                const SizedBox(width: 16),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final loc in locations)
                          ConstrainedBox(
                            // Ab drei Orten höchstens halbe Breite: lange
                            // Orte werden gekürzt, die Zeile bleibt schlank
                            // (der volle Text steht im Sheet und im
                            // Screenreader-Label).
                            constraints: BoxConstraints(
                                maxWidth: locations.length <= 2
                                    ? constraints.maxWidth
                                    : (constraints.maxWidth - 6) / 2),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: chipColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                child: Text(
                                  loc,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelLarge
                                      ?.copyWith(color: onChip),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.edit_outlined, size: 20, color: iconColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
