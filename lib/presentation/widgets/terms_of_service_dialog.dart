import 'package:flutter/material.dart';
import 'common/markdown_dialog.dart';

class TermsOfServiceDialog extends StatelessWidget {
  const TermsOfServiceDialog({super.key});

  static void show(BuildContext context) {
    MarkdownDialog.show(
      context,
      title: 'AGB',
      assetPath: 'assets/legal/terms.md',
    );
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

