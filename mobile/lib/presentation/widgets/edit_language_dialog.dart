import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../view_models/settings_view_model.dart';

void showEditLanguageDialog(BuildContext context, String currentLocale) {
  showDialog(
    context: context,
    builder: (context) => EditLanguageDialog(currentLocale: currentLocale),
  );
}

class EditLanguageDialog extends ConsumerWidget {
  final String currentLocale;

  const EditLanguageDialog({super.key, required this.currentLocale});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.languageSettingTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RadioListTile<String>(
            title: Text(l10n.languageGerman),
            value: 'de',
            groupValue: currentLocale,
            onChanged: (value) => _select(context, ref, value),
          ),
          RadioListTile<String>(
            title: Text(l10n.languageEnglish),
            value: 'en',
            groupValue: currentLocale,
            onChanged: (value) => _select(context, ref, value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }

  void _select(BuildContext context, WidgetRef ref, String? locale) {
    if (locale == null) return;
    ref.read(settingsViewModelProvider.notifier).updateLocale(locale);
    Navigator.of(context).pop();
  }
}
