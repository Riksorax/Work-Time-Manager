import 'package:flutter/material.dart';

import '../../../domain/entities/overtime_freshness.dart';
import '../../../l10n/app_localizations.dart';

/// Anzeige eines unbekannten Gleitzeit-Saldos (#573): ein Strich statt
/// „+00:00“.
const String unknownOvertimeText = '—';

/// Dezenter Hinweis unter einem Gleitzeit-Saldo (#573), einheitlich für
/// Dashboard, Einstellungen und Monatsbericht: ohne Netz „Stand vom letzten
/// Abruf“ bzw. „noch kein Stand gespeichert“. Bei aktuellem Saldo nichts.
class OvertimeFreshnessHint extends StatelessWidget {
  const OvertimeFreshnessHint({
    super.key,
    required this.freshness,
    this.alignment = MainAxisAlignment.center,
  });

  final OvertimeFreshness freshness;
  final MainAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    if (freshness == OvertimeFreshness.current) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    final text = freshness == OvertimeFreshness.cached
        ? l10n.overtimeStaleHint
        : l10n.overtimeUnknownHint;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisAlignment: alignment,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_outlined, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Der Strich für einen unbekannten Saldo, für Screenreader als „unbekannt“.
class UnknownOvertimeValue extends StatelessWidget {
  const UnknownOvertimeValue({super.key, this.style});

  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppLocalizations.of(context).overtimeUnknownValue,
      excludeSemantics: true,
      child: Text(unknownOvertimeText, style: style),
    );
  }
}
