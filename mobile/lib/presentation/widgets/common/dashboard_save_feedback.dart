import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// Zeigt die Snackbar `dashboardSaveError`, wenn die Dashboard-Aktion
/// [result] `false` liefert (Saldo nicht gespeichert, #402). Messenger und
/// Text werden synchron gelesen, damit der Aufruf auch direkt vor dem Schließen
/// eines Dialogs (`Navigator.pop`) funktioniert.
void reportDashboardSave(BuildContext context, Future<bool> result) {
  final messenger = ScaffoldMessenger.of(context);
  final message = AppLocalizations.of(context).dashboardSaveError;
  result.then((ok) {
    if (!ok) messenger.showSnackBar(SnackBar(content: Text(message)));
  });
}
