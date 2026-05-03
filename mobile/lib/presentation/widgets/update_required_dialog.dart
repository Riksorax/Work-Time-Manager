import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/services/version_service.dart';

/// Dialog der angezeigt wird wenn ein App-Update erforderlich ist
class UpdateRequiredDialog extends StatelessWidget {
  final UpdateInfo updateInfo;
  final VersionService versionService;

  const UpdateRequiredDialog({
    required this.updateInfo,
    required this.versionService,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !updateInfo.forceUpdate, // Bei Force-Update nicht schließbar
      child: AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.system_update,
              color: updateInfo.forceUpdate ? Colors.orange : Colors.blue,
            ),
            const SizedBox(width: 8),
            Text(updateInfo.forceUpdate ? 'Update erforderlich' : 'Update verfügbar'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              updateInfo.message ?? updateInfo.defaultMessage,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _buildVersionInfo(context),
          ],
        ),
        actions: [
          if (!updateInfo.forceUpdate)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Später'),
            ),
          FilledButton.icon(
            onPressed: () => _handleUpdate(context),
            icon: const Icon(Icons.download),
            label: const Text('Jetzt updaten'),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionInfo(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildVersionRow('Aktuelle Version:', updateInfo.currentVersion),
          const SizedBox(height: 4),
          _buildVersionRow('Erforderliche Version:', updateInfo.minVersion),
        ],
      ),
    );
  }

  Widget _buildVersionRow(String label, String version) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        Text(version, style: const TextStyle(fontFamily: 'monospace')),
      ],
    );
  }

  Future<void> _handleUpdate(BuildContext context) async {
    // Versuche zuerst Android In-App-Update (falls Android)
    if (Platform.isAndroid && updateInfo.forceUpdate) {
      final success = await versionService.startAndroidInAppUpdate(immediate: true);
      if (success) {
        return; // In-App-Update wurde gestartet
      }
    } else if (Platform.isAndroid && !updateInfo.forceUpdate) {
      final success = await versionService.startAndroidInAppUpdate(immediate: false);
      if (success) {
        if (context.mounted) {
          Navigator.of(context).pop();
        }
        return;
      }
    }

    // Fallback: Öffne Store
    await versionService.openStore();

    if (context.mounted && !updateInfo.forceUpdate) {
      Navigator.of(context).pop();
    }
  }

  /// Zeigt den Dialog an und prüft vorher ob ein Update erforderlich ist
  static Future<void> checkAndShow(
    BuildContext context,
    VersionService versionService,
  ) async {
    final updateInfo = await versionService.checkForRequiredUpdate();

    if (updateInfo != null && context.mounted) {
      await showDialog(
        context: context,
        barrierDismissible: !updateInfo.forceUpdate,
        builder: (context) => UpdateRequiredDialog(
          updateInfo: updateInfo,
          versionService: versionService,
        ),
      );
    }
  }
}
