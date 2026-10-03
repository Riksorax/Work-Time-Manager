import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_lock_provider.dart';
import '../../domain/utils/pin_hash.dart';
import '../../l10n/app_localizations.dart';

/// Dialog zum erstmaligen Festlegen oder Ändern der PIN für die App-Sperre
/// (siehe #223). Drei Schritte: PIN eingeben, PIN wiederholen, Wiederherstellungscode
/// sichern (siehe #288). PIN und Code werden erst am Ende gemeinsam gespeichert.
class PinSetupDialog extends ConsumerStatefulWidget {
  const PinSetupDialog({super.key});

  /// Zeigt den Dialog und gibt `true` zurück, wenn eine PIN erfolgreich
  /// gesetzt wurde, sonst `false` (z.B. bei Abbruch).
  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PinSetupDialog(),
    );
    return result ?? false;
  }

  @override
  ConsumerState<PinSetupDialog> createState() => _PinSetupDialogState();
}

class _PinSetupDialogState extends ConsumerState<PinSetupDialog> {
  final _firstPinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  bool _confirming = false;
  // Nur bis Dialogende im State, wird nie geloggt.
  String? _recoveryCode;
  bool _codeSaved = false;
  String? _error;

  @override
  void dispose() {
    _firstPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  void _onContinue() {
    final pin = _firstPinController.text;
    if (pin.length < 4) {
      setState(() => _error = AppLocalizations.of(context).pinTooShortError);
      return;
    }
    setState(() {
      _confirming = true;
      _error = null;
    });
  }

  Future<void> _onConfirm() async {
    if (_confirmPinController.text != _firstPinController.text) {
      setState(() {
        _error = AppLocalizations.of(context).pinMismatchError;
        _confirmPinController.clear();
      });
      return;
    }
    setState(() {
      _recoveryCode = generateRecoveryCode();
      _error = null;
    });
  }

  Future<void> _onFinish() async {
    final service = ref.read(appLockServiceProvider);
    await service.setPinWithRecoveryCode(
        _firstPinController.text, _recoveryCode!);
    if (mounted) Navigator.of(context).pop(true);
  }

  Widget _buildCodeStep(AppLocalizations l10n) {
    final hadCode = ref.read(appLockServiceProvider).hasRecoveryCode;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.recoveryCodeSaveHint),
          const SizedBox(height: 16),
          Center(
            child: SelectableText(
              formatRecoveryCode(_recoveryCode!),
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontFamily: 'monospace'),
            ),
          ),
          Center(
            child: TextButton.icon(
              onPressed: () => Clipboard.setData(
                  ClipboardData(text: formatRecoveryCode(_recoveryCode!))),
              icon: const Icon(Icons.copy),
              label: Text(l10n.recoveryCodeCopyAction),
            ),
          ),
          if (hadCode) ...[
            Text(l10n.recoveryCodeRegeneratedHint),
            const SizedBox(height: 8),
          ],
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _codeSaved,
            onChanged: (v) => setState(() => _codeSaved = v ?? false),
            title: Text(l10n.recoveryCodeSavedConfirm),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final activeController =
        _confirming ? _confirmPinController : _firstPinController;

    final codeStep = _recoveryCode != null;

    return AlertDialog(
      title: Text(codeStep
          ? l10n.recoveryCodeTitle
          : (_confirming ? l10n.confirmPinTitle : l10n.setPinTitle)),
      content: codeStep
          ? _buildCodeStep(l10n)
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: ValueKey(_confirming),
                  controller: activeController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: _confirming
                        ? l10n.confirmPinFieldLabel
                        : l10n.newPinFieldLabel,
                    errorText: _error,
                    counterText: '',
                  ),
                ),
              ],
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: codeStep
              ? (_codeSaved ? _onFinish : null)
              : (_confirming ? _onConfirm : _onContinue),
          child: Text(_confirming ? l10n.confirmAction : l10n.continueAction),
        ),
      ],
    );
  }
}
