import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

class ErrorDisplay extends StatelessWidget {
  final String error;
  final VoidCallback? onRetry;
  const ErrorDisplay({
    super.key,
    required this.error,
    this.onRetry,
  });
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              l10n.errorOccurredTitle,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: Text(l10n.retryButton),
                onPressed: onRetry,
              ),
            ]
          ],
        ),
      ),
    );
  }
}
