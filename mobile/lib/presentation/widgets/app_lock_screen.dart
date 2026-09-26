import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_lock_provider.dart';
import '../../l10n/app_localizations.dart';

/// Vollflächige Sperre, die über der App angezeigt wird, solange
/// [isAppLockedProvider] `true` ist (siehe #223). Versucht beim Anzeigen
/// automatisch Biometrie; bei Nichtverfügbarkeit/Fehlschlag kann der Nutzer
/// die hinterlegte PIN eingeben oder es erneut mit Biometrie versuchen.
class AppLockScreen extends ConsumerStatefulWidget {
  const AppLockScreen({super.key});

  @override
  ConsumerState<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<AppLockScreen> {
  final _pinController = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometrics());
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _tryBiometrics() async {
    final service = ref.read(appLockServiceProvider);
    if (!await service.isBiometricAvailable()) return;
    final success = await service.authenticateWithBiometrics();
    if (success && mounted) {
      _unlock();
    }
  }

  void _unlock() {
    ref.read(isAppLockedProvider.notifier).state = false;
  }

  void _submitPin() {
    final service = ref.read(appLockServiceProvider);
    if (service.verifyPin(_pinController.text)) {
      _unlock();
    } else {
      setState(() {
        _error = AppLocalizations.of(context).wrongPin;
        _pinController.clear();
      });
    }
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
                Icon(Icons.lock, size: 64, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                Text(l10n.appLockedTitle, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 24),
                TextField(
                  controller: _pinController,
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
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _submitPin,
                  child: Text(l10n.unlockAction),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _tryBiometrics,
                  icon: const Icon(Icons.fingerprint),
                  label: Text(l10n.unlockWithBiometrics),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
