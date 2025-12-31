import 'package:flutter/material.dart';
import 'common/markdown_dialog.dart';

class PrivacyPolicyDialog extends StatelessWidget {
  const PrivacyPolicyDialog({super.key});

  static void show(BuildContext context) {
    MarkdownDialog.show(
      context,
      title: 'Datenschutzerklärung',
      assetPath: 'assets/legal/privacy.md',
    );
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

