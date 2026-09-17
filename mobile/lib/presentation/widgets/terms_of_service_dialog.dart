import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'common/markdown_dialog.dart';
import 'imprint_dialog.dart';

class TermsOfServiceDialog extends StatelessWidget {
  const TermsOfServiceDialog({super.key});

  static void show(BuildContext context) {
    MarkdownDialog.show(
      context,
      title: AppLocalizations.of(context).termsOfServiceTitle,
      assetPath: 'assets/legal/terms.md',
      customLinkHandlers: {
        'imprint.html': () => ImprintDialog.show(context),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

