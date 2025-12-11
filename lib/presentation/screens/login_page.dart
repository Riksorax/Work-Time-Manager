import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_work_time/core/utils/logger.dart';

import '../../core/providers/providers.dart';
import '../../data/repositories/hybrid_work_repository_impl.dart';
import '../../data/repositories/hybrid_overtime_repository_impl.dart';
import '../../domain/services/data_sync_service.dart';
import '../view_models/auth_view_model.dart';
import '../view_models/dashboard_view_model.dart' as dashboard_vm;
import '../widgets/privacy_policy_dialog.dart';
import '../widgets/terms_of_service_dialog.dart';
import 'home_screen.dart';

class LoginPage extends ConsumerStatefulWidget {
  final int returnToIndex;
  const LoginPage({this.returnToIndex = 0, super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Icon/Logo
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withAlpha(26),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/icon/WorkTimeManagerLogo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Title
                Text(
                  'Work Time Manager',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Erfassen Sie Ihre Arbeitszeit',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 48),

                // Login Card
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: colorScheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Login Button
                        FilledButton.icon(
                          icon: const Icon(Icons.login),
                          label: const Text('Mit Google anmelden'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () async {
                // Speichere die Zustimmungen
                final settingsRepository = ref.read(settingsRepositoryProvider);
                await settingsRepository.setAcceptedTermsOfService(true);
                await settingsRepository.setAcceptedPrivacyPolicy(true);

                // Zeige Loading-Dialog
                if (context.mounted) {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (dialogContext) => const AlertDialog(
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Anmeldung läuft...'),
                        ],
                      ),
                    ),
                  );
                }

                try {
                  // Rufe den Use Case über den Provider auf.
                  await ref.read(signInWithGoogleProvider)();

                  // Schließe Loading-Dialog
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }

                  // Automatische Synchronisierung nach Login
                  if (context.mounted) {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (dialogContext) => const AlertDialog(
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Synchronisiere lokale Daten...'),
                          ],
                        ),
                      ),
                    );
                  }

                  try {
                    // Hole die Repositories
                    final workRepository = ref.read(dashboard_vm.workRepositoryProvider);
                    final overtimeRepository = ref.read(dashboard_vm.overtimeRepositoryProvider);

                    // Prüfe ob sie Hybrid-Repositories sind
                    if (workRepository is HybridWorkRepositoryImpl &&
                        overtimeRepository is HybridOvertimeRepositoryImpl) {
                      // Führe Sync durch
                      final result = await DataSyncService.syncAll(
                        localWorkRepository: workRepository.localRepository,
                        firebaseWorkRepository: workRepository.firebaseRepository,
                        localOvertimeRepository: overtimeRepository.localRepository,
                        firebaseOvertimeRepository: overtimeRepository.firebaseRepository,
                      );

                      // Schließe Sync-Dialog
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }

                      // Zeige Ergebnis
                      final workEntriesSynced = result['workEntriesSynced'] as int;
                      final overtimeSynced = result['overtimeSynced'] as bool;
                      final errors = result['errors'] as List<String>;

                      if (context.mounted) {
                        if (workEntriesSynced > 0 || overtimeSynced) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Erfolgreich synchronisiert!\n'
                                'Arbeitseinträge: $workEntriesSynced\n'
                                'Überstunden: ${overtimeSynced ? "Ja" : "Nein"}',
                              ),
                              backgroundColor: errors.isEmpty ? Colors.green : Colors.orange,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      }

                      // Aktualisiere Dashboard nach Sync
                      ref.invalidate(dashboard_vm.dashboardViewModelProvider);
                    } else {
                      // Schließe Sync-Dialog
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    }
                  } catch (syncError) {
                    logger.e('[LoginPage] Fehler bei der Synchronisierung: $syncError');
                    // Schließe Sync-Dialog bei Fehler
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Synchronisierung fehlgeschlagen: $syncError'),
                          backgroundColor: Colors.orange,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  }

                  if (context.mounted) {
                    // Nach erfolgreicher Anmeldung zurück zur ursprünglichen Seite navigieren
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (context) => HomeScreen(initialIndex: widget.returnToIndex)),
                    );
                  }
                } catch (loginError) {
                  logger.e('[LoginPage] Fehler beim Login: $loginError');
                  // Schließe Loading-Dialog bei Fehler
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Anmeldung fehlgeschlagen: $loginError'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                }
              },
                        ),
                        const SizedBox(height: 16),
                        // Legal Notice
                        Center(
                          child: RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              children: [
                                const TextSpan(text: 'Mit der Anmeldung akzeptieren Sie unsere '),
                                TextSpan(
                                  text: 'AGB',
                                  style: TextStyle(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () => TermsOfServiceDialog.show(context),
                                ),
                                const TextSpan(text: ' und '),
                                TextSpan(
                                  text: 'Datenschutzerklärung',
                                  style: TextStyle(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () => PrivacyPolicyDialog.show(context),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Divider
                        Row(
                          children: [
                            Expanded(child: Divider(color: colorScheme.outlineVariant)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'oder',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: colorScheme.outlineVariant)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Skip Button
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (context) => HomeScreen(
                                initialIndex: widget.returnToIndex,
                              )),
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Ohne Anmeldung fortfahren'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}