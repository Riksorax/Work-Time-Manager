import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_lock_provider.dart';
import '../../core/utils/app_navigator.dart';
import '../../domain/utils/app_lock_lockout.dart';
import '../../l10n/app_localizations.dart';
import 'forgot_pin_dialog.dart';
import 'lockout_countdown.dart';
import 'pin_setup_dialog.dart';

/// Vollflächige Sperre, die über der App angezeigt wird, solange
/// [isAppLockedProvider] `true` ist (siehe #223). Versucht beim Anzeigen
/// automatisch Biometrie; bei Nichtverfügbarkeit/Fehlschlag kann der Nutzer
/// die hinterlegte PIN eingeben oder es erneut mit Biometrie versuchen.
class AppLockScreen extends ConsumerStatefulWidget {
  const AppLockScreen({super.key});

  @override
  ConsumerState<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<AppLockScreen>
    with LockoutCountdownMixin<AppLockScreen> {
  final _pinController = TextEditingController();
  final _focusNode = FocusNode();
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    initLockout();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometrics());
  }

  @override
  void dispose() {
    _pinController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _tryBiometrics() async {
    final service = ref.read(appLockServiceProvider);
    final reason = AppLocalizations.of(context).biometricAuthReason;
    if (!await service.isBiometricAvailable()) return;
    final success =
        await service.authenticateWithBiometrics(localizedReason: reason);
    if (success && mounted) {
      // Biometrie-Erfolg beendet auch eine laufende Sperre (siehe #358).
      await service.resetAttempts();
      if (mounted) _unlock();
    }
  }

  @override
  void onLockoutEnded() {
    // Das Feld ist erst im nächsten Frame wieder aktiv.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _unlock() {
    ref.read(isAppLockedProvider.notifier).state = false;
  }

  Future<void> _submitPin() async {
    if (_busy || lockedOut) return;
    setState(() => _busy = true);
    final service = ref.read(appLockServiceProvider);
    final AttemptResult result;
    try {
      result = await service.attemptPin(_pinController.text);
    } catch (_) {
      if (mounted) setState(() => _busy = false);
      rethrow;
    }
    if (!mounted) return;
    switch (result) {
      case AttemptSuccess():
        // Siehe #337: Fokus vor dem Entsperren beenden, sonst kann das
        // Framework noch eine IME-Selection-Änderung für das PIN-Feld
        // verarbeiten, während der Screen durch das Umschalten von
        // isAppLockedProvider schon entfernt wird -> Null-Check-Crash in
        // TextSelectionOverlay.
        FocusScope.of(context).unfocus();
        _unlock();
      case AttemptWrong(:final remaining):
        setState(() {
          _busy = false;
          _error = AppLocalizations.of(context).wrongPin;
          _pinController.clear();
        });
        applyLockout(remaining);
      case AttemptLocked(:final remaining):
        setState(() {
          _busy = false;
          _pinController.clear();
        });
        applyLockout(remaining);
    }
  }

  /// PIN vergessen (siehe #288): erst Identität prüfen, dann neue PIN samt
  /// neuem Code setzen. Die alte PIN bleibt bis zum erfolgreichen Setzen
  /// unverändert gültig. Der Screen liegt oberhalb des Navigators, daher
  /// kommen die Dialoge über [navigatorKey].
  Future<void> _forgotPin() async {
    final verified =
        await ForgotPinDialog.show(navigatorKey.currentContext ?? context);
    if (!verified || !mounted) return;
    final done =
        await PinSetupDialog.show(navigatorKey.currentContext ?? context);
    if (!done || !mounted) return;
    FocusScope.of(context).unfocus();
    _unlock();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock,
                    size: 64, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                Text(l10n.appLockedTitle,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 24),
                TextField(
                  controller: _pinController,
                  focusNode: _focusNode,
                  enabled: !_busy && !lockedOut,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: l10n.enterPinLabel,
                    errorText: _error,
                    counterText: '',
                  ),
                  onSubmitted: (_) => _submitPin(),
                ),
                LockoutNotice(
                  remaining: lockoutRemaining,
                  total: lockoutTotal,
                  expired: lockoutExpired,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: (_busy || lockedOut) ? null : _submitPin,
                  child: Text(l10n.unlockAction),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _tryBiometrics,
                  icon: const Icon(Icons.fingerprint),
                  label: Text(l10n.unlockWithBiometrics),
                ),
                TextButton(
                  onPressed: _forgotPin,
                  child: Text(l10n.forgotPinAction),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
