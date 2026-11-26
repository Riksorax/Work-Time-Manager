import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Beispiel-Befehle der Hilfeseite in Anzeige-Reihenfolge (#584).
///
/// Die Texte kommen aus den ARB-Dateien und müssen zu den Stichwörtern in
/// `android/app/src/main/kotlin/app/work_time_manager/AssistantTimerIntent.kt`
/// passen; `test/android/voice_commands_mapping_test.dart` schickt jeden
/// Text (de und en) durch die nachgebaute Zuordnung.
List<(IconData, String)> voiceTimerCommands(AppLocalizations l10n) => [
      (Icons.play_arrow, l10n.voiceCommandStartDay),
      (Icons.pause, l10n.voiceCommandStartBreak),
      (Icons.play_circle_outline, l10n.voiceCommandEndBreak),
      (Icons.stop, l10n.voiceCommandClockOut),
    ];

/// Abfrage-Befehle (Premium, Anmeldung nötig), siehe [voiceTimerCommands].
List<(IconData, String)> voiceQueryCommands(AppLocalizations l10n) => [
      (Icons.timelapse, l10n.voiceCommandOvertime),
      (Icons.beach_access, l10n.voiceCommandLeave),
      (Icons.trending_up, l10n.voiceCommandTrend),
    ];

/// Hilfeseite „Sprachbefehle“ für den Google Assistant (#584, nur Android).
///
/// Reine Erklärung ohne Zustand; die Befehle selbst verarbeitet
/// `AssistantTimerIntent` (Timer, #280) bzw. der Abfrage-Weg (#287).
class VoiceCommandsPage extends StatelessWidget {
  const VoiceCommandsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.voiceCommandsTitle)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.mic_none, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(l10n.voiceCommandsIntro,
                    style: theme.textTheme.bodyMedium),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _CommandGroup(
            title: l10n.voiceCommandsTimerSection,
            commands: voiceTimerCommands(l10n),
          ),
          const SizedBox(height: 16),
          _CommandGroup(
            title: l10n.voiceCommandsQuerySection,
            commands: voiceQueryCommands(l10n),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline,
                  size: 18, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.voiceCommandsRecognitionHint,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommandGroup extends StatelessWidget {
  const _CommandGroup({required this.title, required this.commands});

  final String title;
  final List<(IconData, String)> commands;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            title,
            style: theme.textTheme.titleSmall
                ?.copyWith(color: theme.colorScheme.primary),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (final (icon, command) in commands)
                ListTile(
                  dense: true,
                  leading: Icon(icon),
                  title: Text(l10n.voiceCommandQuoted(command),
                      style: theme.textTheme.bodyLarge),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
