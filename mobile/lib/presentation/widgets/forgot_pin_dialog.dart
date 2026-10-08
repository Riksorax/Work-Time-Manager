import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_lock_provider.dart';
import '../../core/utils/logger.dart';
import '../../domain/utils/app_lock_lockout.dart';
import '../../l10n/app_localizations.dart';
import '../view_models/auth_view_model.dart';
import 'lockout_countdown.dart';

/// Dialog "PIN vergessen" der App-Sperre (siehe #288). Bestätigt die Identität
/// per Google-Re-Auth (wenn eingeloggt) und/oder per Wiederherstellungscode
/// (wenn gespeichert). Gibt bei verifizierter Identität `true` zurück.
class ForgotPinDialog extends ConsumerStatefulWidget {
  const ForgotPinDialog({super.key});

  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const ForgotPinDialog(),
    );
    return result ?? false;
  }

  @override
  ConsumerState<ForgotPinDialog> createState() => _ForgotPinDialogState();
}

class _ForgotPinDialogState extends ConsumerState<ForgotPinDialog>
    with LockoutCountdownMixin<ForgotPinDialog> {
  final _codeController = TextEditingController();
  String? _codeError;
  String? _reauthError;
  bool _busy = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    initLockout();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _reauth() async {
    setState(() {
      _busy = true;
      _reauthError = null;
    });
    var ok = false;
    try {
      ok = await ref.read(reauthenticateProvider)();
    } catch (e) {
      // Nur der Fehlertyp, nie sensible Inhalte (siehe #288).
      logger.e('PIN-Reset: Re-Auth warf ${e.runtimeType}');
    } finally {
      if (mounted && !ok) {
        setState(() {
          _busy = false;
          _reauthError = AppLocalizations.of(context).reauthFailedError;
        });
      }
    }
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _submitCode() async {
    if (_submitting || lockedOut) return;
    setState(() => _submitting = true);
    final service = ref.read(appLockServiceProvider);
    final AttemptResult result;
    try {
      result = await service.attemptRecoveryCode(_codeController.text);
    } catch (_) {
      if (mounted) setState(() => _submitting = false);
      rethrow;
    }
    if (!mounted) return;
    switch (result) {
      case AttemptSuccess():
        Navigator.of(context).pop(true);
      case AttemptWrong(:final remaining):
        setState(() {
          _submitting = false;
          _codeError = AppLocalizations.of(context).wrongRecoveryCodeError;
          _codeController.clear();
        });
        applyLockout(remaining);
      case AttemptLocked(:final remaining):
        setState(() {
          _submitting = false;
          _codeController.clear();
        });
        applyLockout(remaining);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final loggedIn = ref.watch(authStateProvider).value != null;
    final hasCode = ref.watch(appLockServiceProvider).hasRecoveryCode;

    final children = <Widget>[];
    if (loggedIn) {
      children
        ..add(Text(l10n.reauthRequiredHint))
        ..add(const SizedBox(height: 8))
        ..add(FilledButton(
          onPressed: _busy ? null : _reauth,
          child: Text(l10n.reauthConfirmAction),
        ));
      if (_reauthError != null) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(_reauthError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ));
      }
    }
    if (hasCode) {
      if (loggedIn) children.add(const SizedBox(height: 16));
      children
        ..add(TextField(
          controller: _codeController,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          enableSuggestions: false,
          enabled: !_submitting && !lockedOut,
          decoration: InputDecoration(
            labelText: l10n.enterRecoveryCodeLabel,
            errorText: _codeError,
          ),
          onSubmitted: (_) => _submitCode(),
        ))
        ..add(LockoutNotice(
          remaining: lockoutRemaining,
          total: lockoutTotal,
          expired: lockoutExpired,
        ))
        ..add(const SizedBox(height: 8))
        ..add(FilledButton(
          onPressed: (_submitting || lockedOut) ? null : _submitCode,
          child: Text(l10n.resetPinAction),
        ));
    }
    if (!loggedIn && !hasCode) {
      children.add(Text(l10n.noRecoveryCodeHint));
    }

    return AlertDialog(
      title: Text(l10n.forgotPinTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}
