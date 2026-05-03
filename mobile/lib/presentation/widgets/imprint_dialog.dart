import 'package:flutter/material.dart';
import 'common/markdown_dialog.dart';

class ImprintDialog extends StatelessWidget {
  const ImprintDialog({super.key});

  static void show(BuildContext context) {
    MarkdownDialog.show(
      context,
      title: 'Impressum',
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
