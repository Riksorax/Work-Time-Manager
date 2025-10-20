import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/hybrid_work_repository_impl.dart';
import '../../data/repositories/hybrid_overtime_repository_impl.dart';
import '../../domain/services/data_sync_service.dart';
import '../view_models/auth_view_model.dart';
import '../view_models/dashboard_view_model.dart' as dashboard_vm;
import 'home_screen.dart';

class LoginPage extends ConsumerWidget {
  final bool returnToReports;
  const LoginPage({this.returnToReports = false, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anmelden'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.login), // Hier könnte ein Google-Icon stehen
              label: const Text('Mit Google anmelden'),
              onPressed: () async {
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
                    print('[LoginPage] Fehler bei der Synchronisierung: $syncError');
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
                    // Nach erfolgreicher Anmeldung zur Startseite oder Berichtsseite navigieren
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (context) => const HomeScreen(initialIndex: 1)),
                    );
                  }
                } catch (loginError) {
                  print('[LoginPage] Fehler beim Login: $loginError');
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
            TextButton(
              child: const Text('Überspringen'),
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => HomeScreen(
                    initialIndex: returnToReports ? 1 : 0,
                  )),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}