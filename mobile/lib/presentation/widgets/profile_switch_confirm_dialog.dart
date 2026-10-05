import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Bestätigung vor einem Profilwechsel, während im Dashboard noch ein Timer
/// läuft (#388). Liefert `true` bei "Beenden und wechseln", sonst `false`
/// (auch bei `null`).
Future<bool> showProfileSwitchConfirmDialog(
  BuildContext context, {
  required String fromName,
  required String toName,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      final l10n = AppLocalizations.of(dialogContext);
      return AlertDialog(
        title: Text(l10n.switchWhileRunningTitle),
        content: Text(l10n.switchWhileRunningText(fromName, toName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.stopAndSwitchButton),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
