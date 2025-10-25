import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/providers/providers.dart';
import '../../data/repositories/hybrid_work_repository_impl.dart';
import '../../data/repositories/hybrid_overtime_repository_impl.dart';
import '../../domain/services/data_sync_service.dart';
import '../view_models/auth_view_model.dart';
import '../view_models/dashboard_view_model.dart' as dashboard_vm;
import '../view_models/settings_view_model.dart';
import '../view_models/theme_view_model.dart';
import '../widgets/add_adjustment_modal.dart';
import '../widgets/edit_target_hours_modal.dart';
import '../widgets/edit_workdays_modal.dart';
import '../widgets/update_required_dialog.dart';
import '../widgets/privacy_policy_dialog.dart';
import '../widgets/imprint_dialog.dart';
import '../widgets/terms_of_service_dialog.dart';
import '../widgets/notification_settings_dialog.dart';
import 'login_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settingsValue = ref.watch(settingsViewModelProvider);
    final themeMode = ref.watch(themeViewModelProvider);
    final themeNotifier = ref.read(themeViewModelProvider.notifier);
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Einstellungen'),
      ),
      body: settingsValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Fehler: $err')),
        data: (settingsState) {
          final settings = settingsState.settings;
          return ListView(
            children: [
              const SizedBox(height: 16),
              _buildProfileSection(context, ref),
              const SizedBox(height: 8),
              _buildAuthButton(context, ref),
              const SizedBox(height: 8),
              const SizedBox(height: 16),
              const Divider(height: 1),
              ListTile(
                title: const Text('Soll-Arbeitsstunden'),
                subtitle: Text(
                  '${settings.weeklyTargetHours.toStringAsFixed(1)} h/Woche',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  showEditTargetHoursModal(
                    context,
                    settings.weeklyTargetHours,
                  );
                },
              ),
              ListTile(
                title: const Text('Arbeitstage pro Woche'),
                subtitle: Text(
                  '${settings.workdaysPerWeek} Tage',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  showEditWorkdaysModal(
                    context,
                    settings.workdaysPerWeek,
                  );
                },
              ),
              ListTile(
                title: const Text('Tägliche Soll-Arbeitszeit'),
                subtitle: Text(
                  '≈ ${settings.workdaysPerWeek > 0 ? (settings.weeklyTargetHours / settings.workdaysPerWeek).toStringAsFixed(1) : '0.0'} h/Tag',
                ),
              ),
              const Divider(height: 1),
              const SizedBox(height: 16),
              _buildOvertimeBalance(context, settingsState.overtimeBalance),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => const AddAdjustmentModal(),
                    );
                  },
                  child: const Text('Überstunden / Minusstunden anpassen'),
                ),
              ),
              const SizedBox(height: 16),
              _buildDataSyncSection(context, ref, authState),
              const SizedBox(height: 16),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Design'),
                subtitle: Text(themeMode == ThemeMode.dark ? 'Dunkel' : 'Hell'),
                value: themeMode == ThemeMode.dark,
                onChanged: (isDark) {
                  themeNotifier.setTheme(isDark ? ThemeMode.dark : ThemeMode.light);
                },
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Benachrichtigungen'),
                subtitle: settingsState.settings.notificationsEnabled
                    ? Text('Aktiviert um ${settingsState.settings.notificationTime} Uhr')
                    : const Text('Deaktiviert'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  NotificationSettingsDialog.show(context, settingsState.settings);
                },
              ),
              const Divider(height: 1),
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  final version = snapshot.data?.version ?? '...';
                  return ListTile(
                    title: const Text('Version'),
                    trailing: Text(version),
                  );
                },
              ),
              // DEBUG: Test-Button für Version-Check (nur im Debug-Modus)
              if (kDebugMode)
                ListTile(
                  leading: const Icon(Icons.bug_report, color: Colors.orange),
                  title: const Text('🧪 TEST: Version Check'),
                  subtitle: const Text('Update-Dialog manuell anzeigen'),
                  onTap: () async {
                    final versionService = ref.read(versionServiceProvider);
                    await UpdateRequiredDialog.checkAndShow(context, versionService);
                  },
                ),
              ListTile(
                title: const Text('Impressum'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => ImprintDialog.show(context),
              ),
              ListTile(
                title: const Text('AGB'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => TermsOfServiceDialog.show(context),
              ),
              ListTile(
                title: const Text('Datenschutz'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => PrivacyPolicyDialog.show(context),
              ),
              if (authState.asData?.value != null) ...[
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.delete_forever, color: theme.colorScheme.error),
                  title: Text('Account löschen', style: TextStyle(color: theme.colorScheme.error)),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Account endgültig löschen'),
                        content: const Text(
                            'Warnung: Diese Aktion kann nicht rückgängig gemacht werden. Alle Ihre Daten, einschließlich der Arbeitszeiterfassung, werden dauerhaft gelöscht.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: const Text('Abbrechen'),
                          ),
                          FilledButton(
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                              ref.read(deleteAccountProvider)();
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: theme.colorScheme.error,
                            ),
                            child: const Text('Endgültig löschen'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildDataSyncSection(BuildContext context, WidgetRef ref, AsyncValue authState) {
    final isLoggedIn = authState.asData?.value != null;

    if (!isLoggedIn) {
      // Zeige Hinweis, dass Daten lokal gespeichert werden
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.cloud_off, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 12),
                    Text(
                      'Offline-Modus',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ihre Daten werden lokal auf diesem Gerät gespeichert. '
                  'Melden Sie sich an, um Ihre Daten in der Cloud zu sichern und geräteübergreifend zu synchronisieren.',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Zeige Sync-Button für eingeloggte Benutzer
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ElevatedButton.icon(
        onPressed: () => _performSync(context, ref),
        icon: const Icon(Icons.cloud_sync),
        label: const Text('Lokale Daten zu Cloud synchronisieren'),
      ),
    );
  }

  Future<void> _performSync(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);

    // Zeige Loading-Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Synchronisiere Daten...'),
          ],
        ),
      ),
    );

    try {
      // Hole die Repositories
      final workRepository = ref.read(dashboard_vm.workRepositoryProvider);
      final overtimeRepository = ref.read(dashboard_vm.overtimeRepositoryProvider);

      // Prüfe ob sie Hybrid-Repositories sind
      if (workRepository is! HybridWorkRepositoryImpl ||
          overtimeRepository is! HybridOvertimeRepositoryImpl) {
        throw Exception('Repositories sind nicht vom Typ Hybrid');
      }

      // Führe Sync durch
      final result = await DataSyncService.syncAll(
        localWorkRepository: workRepository.localRepository,
        firebaseWorkRepository: workRepository.firebaseRepository,
        localOvertimeRepository: overtimeRepository.localRepository,
        firebaseOvertimeRepository: overtimeRepository.firebaseRepository,
      );

      // Schließe Loading-Dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Zeige Ergebnis
      final workEntriesSynced = result['workEntriesSynced'] as int;
      final overtimeSynced = result['overtimeSynced'] as bool;
      final errors = result['errors'] as List<String>;

      if (errors.isEmpty) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Synchronisierung erfolgreich!\n'
              'Arbeitseinträge: $workEntriesSynced\n'
              'Überstunden: ${overtimeSynced ? "Ja" : "Nein"}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );

        // Aktualisiere Dashboard nach Sync
        ref.invalidate(dashboard_vm.dashboardViewModelProvider);
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Synchronisierung mit Fehlern:\n'
              'Arbeitseinträge: $workEntriesSynced\n'
              'Fehler: ${errors.join(", ")}',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      // Schließe Loading-Dialog bei Fehler
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text('Fehler bei der Synchronisierung: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Widget _buildOvertimeBalance(BuildContext context, Duration overtimeBalance) {
    final bool isNegative = overtimeBalance.isNegative;
    final Duration absDuration = overtimeBalance.abs();

    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(absDuration.inHours);
    final minutes = twoDigits(absDuration.inMinutes.remainder(60));
    final sign = isNegative ? '-' : '+';
    final formattedOvertime = '$sign$hours:$minutes';

    return Column(
      children: [
        Text(
          'Gleitzeit-Bilanz',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          formattedOvertime,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: isNegative ? Colors.red : Colors.green,
              ),
        ),
      ],
    );
  }

  Widget _buildProfileSection(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.grey,
                  child: Icon(Icons.person, size: 30, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Text('Nicht angemeldet', style: theme.textTheme.titleLarge),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
                child: user.photoURL == null
                    ? Text(user.displayName?.isNotEmpty == true
                        ? user.displayName![0].toUpperCase()
                        : '?')
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName ?? 'Benutzer',
                      style: theme.textTheme.titleLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (user.email != null)
                      Text(
                        user.email!,
                        style: theme.textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.0),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 30,
              backgroundColor: Colors.red,
              child: Icon(Icons.error, size: 30, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Text('Fehler beim Laden', style: theme.textTheme.titleLarge),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthButton(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage(returnToIndex: 2)),
                );
              },
              icon: const Icon(Icons.login),
              label: const Text('Anmelden'),
            ),
          );
        } else {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: OutlinedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Abmelden'),
                    content: const Text('Möchten Sie sich wirklich abmelden?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Abbrechen'),
                      ),
                      FilledButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          ref.read(signOutProvider)();
                          // Invalidiere Repositories und Dashboard nach Abmeldung
                          ref.invalidate(dashboard_vm.workRepositoryProvider);
                          ref.invalidate(dashboard_vm.overtimeRepositoryProvider);
                          ref.invalidate(dashboard_vm.dashboardViewModelProvider);
                        },
                        child: const Text('Abmelden'),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.logout),
              label: const Text('Abmelden'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
              ),
            ),
          );
        }
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
