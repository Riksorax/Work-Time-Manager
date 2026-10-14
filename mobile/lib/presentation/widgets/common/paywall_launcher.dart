import 'package:flutter/material.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

import '../../../core/utils/logger.dart';
import '../../../core/utils/revenuecat_state.dart';
import '../../../l10n/app_localizations.dart';

/// Zeigt die RevenueCat-Paywall in einem Fullscreen-Modal an. Gemeinsam
/// genutzt von allen Stellen, an denen ein Premium-Feature (Berichte,
/// zusätzliche Arbeitszeit-Profile, ...) direkt zum Kauf führen soll.
void showPaywall(BuildContext context) {
  // Ohne konfiguriertes RevenueCat (fehlender/ungültiger Key) keine Paywall
  if (!revenueCatConfigured) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context).paywallUnavailable,
        ),
      ),
    );
    return;
  }

  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      decoration: BoxDecoration(
        color: Theme.of(ctx).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: PaywallView(
        onDismiss: () {
          if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
        },
        // Ohne diese Callbacks bleibt "Abo wiederherstellen" stumm.
        onRestoreCompleted: (customerInfo) {
          if (!ctx.mounted) return;
          if (customerInfo.entitlements.active.isNotEmpty) {
            Navigator.of(ctx).pop();
            messenger.showSnackBar(
              SnackBar(content: Text(l10n.paywallRestoreSuccess)),
            );
          } else {
            _showRestoreDialog(ctx, l10n.paywallRestoreNothingFound);
          }
        },
        onRestoreError: (error) {
          logger.w('Abo wiederherstellen fehlgeschlagen: ${error.message}');
          if (!ctx.mounted) return;
          _showRestoreDialog(ctx, l10n.paywallRestoreError);
        },
      ),
    ),
  );
}

/// Meldung über der Paywall (ein Snackbar läge hinter dem Bottom Sheet).
void _showRestoreDialog(BuildContext context, String message) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
        ),
      ],
    ),
  );
}
