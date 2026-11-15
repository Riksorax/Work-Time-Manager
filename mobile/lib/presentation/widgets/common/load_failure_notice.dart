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
  });

  final String message;
  final VoidCallback onRetry;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              offline ? Icons.cloud_off_outlined : Icons.error_outline,
              color: offline
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.error,
            ),
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
