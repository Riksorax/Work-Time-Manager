import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// Verständliche Meldung bei einem Ladefehler mit „Erneut versuchen“ (#573),
/// statt des rohen Ausnahmetexts. Stil wie der Fehlerzustand des Jahres-Tabs.
/// Mit [offline] steht „Keine Verbindung“ als Titel und ein Wolken-Symbol.
class LoadFailureNotice extends StatelessWidget {
  const LoadFailureNotice({
    super.key,
    required this.message,
    required this.onRetry,
    this.offline = false,
    this.compact = false,
  });

  final String message;
  final VoidCallback onRetry;
  final bool offline;

  /// Schmale Zeile statt Karte mit Block (Dashboard, #573): Symbol links,
  /// Titel und Satz daneben, „Erneut versuchen“ als Text-Button darunter.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final icon = Icon(
      offline ? Icons.cloud_off_outlined : Icons.error_outline,
      color: offline
          ? theme.colorScheme.onSurfaceVariant
          : theme.colorScheme.error,
    );
    if (compact) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(padding: const EdgeInsets.only(top: 2), child: icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (offline)
                      Text(l10n.reportsOfflineTitle,
                          style: theme.textTheme.titleSmall),
                    Text(message, style: theme.textTheme.bodySmall),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: Text(l10n.retryButton),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(height: 8),
            if (offline) ...[
              Text(
                l10n.reportsOfflineTitle,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
            ],
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retryButton),
            ),
          ],
        ),
      ),
    );
  }
}
