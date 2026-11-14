import 'package:flutter/material.dart';

/// Eine Aktion in der [ReportActionRow].
class ReportAction {
  final IconData icon;

  /// Sichtbare Beschriftung; wird bei Platzmangel mit „…“ gekürzt.
  final String label;

  /// Vollständige Beschriftung für Tooltip (langer Druck) und Screenreader.
  /// Fehlt sie, gilt [label].
  final String? fullLabel;
  final VoidCallback onPressed;

  const ReportAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.fullLabel,
  });
}

/// Aktionszeile der Berichte (Wochen- und Monats-Tab, #535): alle Aktionen
/// nebeneinander in einer Zeile, jede mit gleicher Breite. Reicht der Platz
/// nicht, wird die Beschriftung einzeilig mit „…“ gekürzt; Tooltip und
/// Screenreader bekommen immer den vollen Text.
class ReportActionRow extends StatelessWidget {
  final List<ReportAction> actions;

  const ReportActionRow({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final a in actions)
          Expanded(
            child: Tooltip(
              message: a.fullLabel ?? a.label,
              excludeFromSemantics: true,
              child: Semantics(
                button: true,
                label: a.fullLabel ?? a.label,
                onTap: a.onPressed,
                excludeSemantics: true,
                child: TextButton.icon(
                  onPressed: a.onPressed,
                  icon: Icon(a.icon),
                  label: Text(a.label,
                      overflow: TextOverflow.ellipsis, maxLines: 1),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
