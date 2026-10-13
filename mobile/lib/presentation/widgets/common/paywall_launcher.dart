import 'package:flutter/material.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

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
      ),
    ),
  );
}
