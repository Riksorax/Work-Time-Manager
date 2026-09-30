import 'package:flutter/material.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

import '../../../l10n/app_localizations.dart';

/// Zeigt die RevenueCat-Paywall in einem Fullscreen-Modal an. Gemeinsam
/// genutzt von allen Stellen, an denen ein Premium-Feature (Berichte,
/// zusätzliche Arbeitszeit-Profile, ...) direkt zum Kauf führen soll.
const _rcAndroidKey = String.fromEnvironment('RC_ANDROID_KEY');

void showPaywall(BuildContext context) {
  // Im lokalen Test ohne gültigen RC-Key kein Paywall öffnen
  if (_rcAndroidKey.isEmpty) {
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
