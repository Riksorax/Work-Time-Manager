import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers/app_lock_provider.dart';
import '../../core/providers/providers.dart' as core_providers;
import '../../core/providers/subscription_provider.dart';
import '../../core/services/app_lock_service.dart';
import '../../data/repositories/hybrid_work_repository_impl.dart';
import '../../data/repositories/hybrid_overtime_repository_impl.dart';
import '../../data/repositories/firebase_overtime_repository_impl.dart';
import '../../domain/entities/bundesland.dart';
import '../../domain/services/data_sync_service.dart';
import '../../domain/utils/weekday_labels.dart';
import '../view_models/auth_view_model.dart';
import '../view_models/dashboard_view_model.dart' as dashboard_vm;
import '../view_models/settings_view_model.dart';
import '../view_models/theme_view_model.dart';
import '../widgets/add_adjustment_modal.dart';
import '../widgets/edit_target_hours_modal.dart';
import '../widgets/edit_timezone_modal.dart';
import '../widgets/edit_workdays_modal.dart';
import '../widgets/notification_settings_dialog.dart';
import '../widgets/pin_setup_dialog.dart';
import '../widgets/common/responsive_center.dart';
import 'app_info_page.dart';
import 'login_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsValue = ref.watch(settingsViewModelProvider);
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

          final topSection = [
            const SizedBox(height: 16),
            _buildProfileSection(context, ref),
            const SizedBox(height: 8),
            _buildAuthButton(context, ref),
            const SizedBox(height: 8),
            _buildSubscriptionSection(context, ref),
            const SizedBox(height: 16),
          ];

          final leftColumnChildren = [
            ...topSection,
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
              title: const Text('Arbeitstage'),
              subtitle: Text(formatWorkdays(settings.workdays)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                showEditWorkdaysModal(
                  context,
                  settings.workdays,
                );
              },
            ),
            ListTile(
              title: const Text('Tägliche Soll-Arbeitszeit'),
              subtitle: Text(
                '≈ ${settings.workdays.isNotEmpty ? (settings.weeklyTargetHours / settings.workdays.length).toStringAsFixed(1) : '0.0'} h/Tag',
              ),
            ),
            ListTile(
              title: const Text('Zeitzone'),
              subtitle: Text(settings.timezoneOverride ?? 'Systemstandard'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                showEditTimezoneModal(context, settings.timezoneOverride);
              },
            ),
            const Divider(height: 1),
            const SizedBox(height: 16),
            _buildOvertimeBalance(context, settingsState.overtimeBalance, settingsState.lastOvertimeUpdate),
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
          ];

          final rightColumnChildren = [
            const Divider(height: 1),
            SwitchListTile(
              title: const Text('Design'),
              subtitle: Text(Theme.of(context).brightness == Brightness.dark ? 'Dunkel' : 'Hell'),
              value: Theme.of(context).brightness == Brightness.dark,
              onChanged: (isDark) {
                themeNotifier.setTheme(isDark ? ThemeMode.dark : ThemeMode.light);
              },
            ),
            const Divider(height: 1),
            SwitchListTile(
              title: const Text('24-Stunden-Format'),
              subtitle: Text(settingsState.settings.use24HourFormat
                  ? 'z. B. 18:00'
                  : 'z. B. 6:00 PM'),
              value: settingsState.settings.use24HourFormat,
              onChanged: (use24Hour) {
                ref
                    .read(settingsViewModelProvider.notifier)
                    .updateUse24HourFormat(use24Hour);
              },
            ),
            const Divider(height: 1),
            ListTile(
              title: const Text('Bundesland'),
              subtitle: Text(
                settings.bundesland?.displayName ??
                    'Nicht ausgewählt – keine Feiertagsmarkierung im Kalender',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                _showBundeslandPicker(context, ref, settings.bundesland);
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
            if (!kIsWeb) ...[
              const Divider(height: 1),
              const _AppLockSection(),
            ],
            const Divider(height: 1),
            ListTile(
              title: const Text('Über die App'),
              subtitle: const Text('Version, Impressum, Datenschutz & mehr'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AppInfoPage()),
                );
              },
            ),
          ];

          return ResponsiveCenter(
            maxContentWidth: 1200,
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 900) {
                  return SingleChildScrollView(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: leftColumnChildren,
                          ),
                        ),
                        const SizedBox(width: 32),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Invisible spacer to match left column's top section
                              Visibility(
                                maintainSize: true,
                                maintainAnimation: true,
                                maintainState: true,
                                visible: false,
                                child: Column(
                                  children: topSection,
                                ),
                              ),
                              ...rightColumnChildren,
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                } else {
                  return ListView(
                    children: [
                      ...leftColumnChildren,
                      ...rightColumnChildren,
                    ],
                  );
                }
              },
            ),
          );
        },
      ),
    );
  }

  void _showBundeslandPicker(BuildContext context, WidgetRef ref, Bundesland? current) {
    showDialog(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Bundesland für Feiertage'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              ref.read(settingsViewModelProvider.notifier).updateBundesland(null);
            },
            child: Row(
              children: [
                if (current == null) const Icon(Icons.check, size: 18) else const SizedBox(width: 18),
                const SizedBox(width: 8),
                const Text('Keine Auswahl'),
              ],
            ),
          ),
          for (final bundesland in Bundesland.values)
            SimpleDialogOption(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                ref.read(settingsViewModelProvider.notifier).updateBundesland(bundesland);
              },
              child: Row(
                children: [
                  if (current == bundesland)
                    const Icon(Icons.check, size: 18)
                  else
                    const SizedBox(width: 18),
                  const SizedBox(width: 8),
                  Text(bundesland.displayName),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Abo-Verwaltung für Premium-Nutzer (siehe #220): zeigt Laufzeit/
  /// Verlängerungsstatus aus RevenueCat an und verlinkt auf die store-eigene
  /// Verwaltungsseite (`getManagementURL()`), statt eine eigene Kündigungs-
  /// /Verlängerungslogik nachzubauen.
  Widget _buildSubscriptionSection(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(isPremiumProvider);
    if (!isPremium) return const SizedBox.shrink();

    final entitlement = ref.watch(activeEntitlementProvider);
    final expirationDateString = entitlement?.expirationDate;
    final expirationDate =
        expirationDateString != null ? DateTime.tryParse(expirationDateString) : null;
    final willRenew = entitlement?.willRenew ?? false;

    String? statusText;
    if (expirationDate != null) {
      final formattedDate = DateFormat('dd.MM.yyyy').format(expirationDate);
      statusText = willRenew
          ? 'Verlängert sich automatisch am $formattedDate'
          : 'Läuft aus am $formattedDate';
    }

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
                  const Icon(Icons.subscriptions, color: Colors.orange),
                  const SizedBox(width: 12),
                  Text('Dein Abo', style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
              if (statusText != null) ...[
                const SizedBox(height: 8),
                Text(statusText, style: const TextStyle(fontSize: 14)),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _openSubscriptionManagement(context),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Abo verwalten'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openSubscriptionManagement(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final urlString = await getSubscriptionManagementUrl();
    if (urlString == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Abo-Verwaltung ist auf diesem Gerät nicht verfügbar. '
            'Bitte über den App Store bzw. Play Store verwalten.',
          ),
        ),
      );
      return;
    }

    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('Der Abo-Verwaltungslink konnte nicht geöffnet werden.')),
      );
    }
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
      final workRepository = ref.read(core_providers.workRepositoryProvider);
      final overtimeRepository = ref.read(core_providers.overtimeRepositoryProvider);

      // Hole die aktuelle userId
      final currentUser = ref.read(core_providers.firebaseAuthProvider).currentUser;
      final userId = currentUser?.uid;

      // Prüfe ob sie Hybrid-Repositories sind und User eingeloggt ist
      if (workRepository is! HybridWorkRepositoryImpl ||
          overtimeRepository is! HybridOvertimeRepositoryImpl ||
          userId == null) {
        throw Exception('Repositories sind nicht vom Typ Hybrid oder User nicht eingeloggt');
      }

      // Erstelle frisches Firebase-Repository mit korrekter userId
      final freshFirebaseOvertimeRepo = FirebaseOvertimeRepositoryImpl(
        dataSource: ref.read(core_providers.firestoreDataSourceProvider),
        userId: userId,
      );

      // Führe Sync durch
      final result = await DataSyncService.syncAll(
        localWorkRepository: workRepository.localRepository,
        firebaseWorkRepository: workRepository.firebaseRepository,
        localOvertimeRepository: overtimeRepository.localRepository,
        firebaseOvertimeRepository: freshFirebaseOvertimeRepo,
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

  Widget _buildOvertimeBalance(BuildContext context, Duration overtimeBalance, DateTime? lastUpdate) {
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
        if (lastUpdate != null && lastUpdate.isAfter(DateTime(2000))) ...[
          const SizedBox(height: 4),
          Text(
            'Letzte manuelle Änderung: ${DateFormat('dd.MM.yyyy').format(lastUpdate)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
      ],
    );
  }

  Widget _buildProfileSection(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authStateProvider);
    final isPremium = ref.watch(isPremiumProvider);

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
                    if (isPremium) ...[
                      const SizedBox(height: 4),
                      const _PremiumBadge(),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_forever, color: theme.colorScheme.error),
                tooltip: 'Account löschen',
                onPressed: () {
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
                          ref.invalidate(core_providers.workRepositoryProvider);
                          ref.invalidate(core_providers.overtimeRepositoryProvider);
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

/// PIN-/Biometrie-Sperre der App (siehe #223). Eigenes
/// [ConsumerStatefulWidget], da der Aktivierungsstatus direkt aus
/// [AppLockService]/SharedPreferences kommt und nicht über
/// [settingsViewModelProvider] läuft (rein lokale, geräteweite Einstellung
/// ohne Firestore-Sync).
class _AppLockSection extends ConsumerStatefulWidget {
  const _AppLockSection();

  @override
  ConsumerState<_AppLockSection> createState() => _AppLockSectionState();
}

class _AppLockSectionState extends ConsumerState<_AppLockSection> {
  @override
  Widget build(BuildContext context) {
    final service = ref.watch(appLockServiceProvider);
    final isEnabled = service.isEnabled;

    return Column(
      children: [
        SwitchListTile(
          title: const Text('PIN-/Biometrie-Sperre'),
          subtitle: Text(isEnabled
              ? 'App wird beim Start und aus dem Hintergrund gesperrt'
              : 'Deaktiviert'),
          value: isEnabled,
          onChanged: (value) => _onToggle(context, value, service),
        ),
        if (isEnabled)
          ListTile(
            title: const Text('PIN ändern'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => PinSetupDialog.show(context),
          ),
      ],
    );
  }

  Future<void> _onToggle(BuildContext context, bool value, AppLockService service) async {
    if (value) {
      if (!service.hasPin) {
        final success = await PinSetupDialog.show(context);
        if (!success) return;
      }
      await service.setEnabled(true);
    } else {
      await service.setEnabled(false);
    }
    // Provider selbst ist nicht reaktiv (synchrone SharedPreferences-Reads) -
    // setState erzwingt einen Rebuild dieses Abschnitts nach der Änderung.
    if (mounted) setState(() {});
  }
}

class _PremiumBadge extends StatelessWidget {
  const _PremiumBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.orange,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium, size: 14, color: Colors.white),
          SizedBox(width: 4),
          Text(
            'Premium',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}