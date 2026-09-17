import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_lock_provider.dart';
import '../../l10n/app_localizations.dart';

/// Dialog zum erstmaligen Festlegen oder Ändern der PIN für die App-Sperre
/// (siehe #223). Zwei Schritte: PIN eingeben, PIN zur Bestätigung wiederholen.
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
    final service = ref.read(appLockServiceProvider);
    await service.setPin(_firstPinController.text);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final activeController = _confirming ? _confirmPinController : _firstPinController;

    return AlertDialog(
      title: Text(_confirming ? l10n.confirmPinTitle : l10n.setPinTitle),
      content: Column(
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
              labelText: _confirming ? l10n.confirmPinFieldLabel : l10n.newPinFieldLabel,
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
          onPressed: _confirming ? _onConfirm : _onContinue,
          child: Text(_confirming ? l10n.confirmAction : l10n.continueAction),
        ),
      ],
    );
  }
}
