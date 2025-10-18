import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../view_models/auth_view_model.dart';
import '../view_models/settings_view_model.dart';
import '../view_models/theme_view_model.dart';
import '../widgets/add_adjustment_modal.dart';
import '../widgets/edit_target_hours_modal.dart';
import '../widgets/edit_workdays_modal.dart';
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
                title: Text('Benachrichtigungen', style: theme.textTheme.titleMedium),
              ),
              SwitchListTile(
                title: const Text('Arbeitsbeginn'),
                value: false,
                onChanged: (value) {},
              ),
              SwitchListTile(
                title: const Text('Arbeitsende'),
                value: false,
                onChanged: (value) {},
              ),
              SwitchListTile(
                title: const Text('Pausen'),
                value: false,
                onChanged: (value) {},
              ),
              const Divider(height: 1),
              if (authState.asData?.value != null) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.sync_alt),
                  title: const Text('Alte Daten migrieren'),
                  subtitle: const Text('Für neue Speicherstruktur'),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Datenmigration'),
                        content: const Text(
                            'Möchten Sie Ihre alten Daten jetzt zur neuen monatlichen Struktur migrieren? Dieser Vorgang kann nicht rückgängig gemacht werden.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: const Text('Abbrechen'),
                          ),
                          FilledButton(
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                              ref.read(settingsViewModelProvider.notifier).migrateWorkEntries();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Migration wird gestartet...')),
                              );
                            },
                            child: const Text('Migrieren'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
              const Divider(height: 1),
              const ListTile(
                title: Text('Version'),
                trailing: Text('1.0.0'),
              ),
              ListTile(
                title: const Text('Impressum'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
              ListTile(
                title: const Text('Datenschutz'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
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
                  MaterialPageRoute(builder: (context) => const LoginPage()),
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
