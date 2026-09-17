import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'common/markdown_dialog.dart';

class ImprintDialog extends StatelessWidget {
  const ImprintDialog({super.key});

  static void show(BuildContext context) {
    MarkdownDialog.show(
      context,
      title: AppLocalizations.of(context).imprintTitle,
      assetPath: 'assets/legal/imprint.md',
    );
  }

  @override
  Widget build(BuildContext context) {
    // Falls das Widget direkt verwendet wird (fallback), öffnen wir einfach den Dialog.
    // Idealerweise sollte immer die statische 'show'-Methode genutzt werden.
    return const SizedBox.shrink(); 
  }
}
