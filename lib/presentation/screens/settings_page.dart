import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../view_models/auth_view_model.dart';
import '../view_models/settings_view_model.dart';
import '../view_models/theme_view_model.dart';
import '../widgets/edit_target_hours_modal.dart';
import 'login_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Holen der State und Notifier für Settings und Theme
    final settingsState = ref.watch(settingsViewModelProvider);
    final themeMode = ref.watch(themeViewModelProvider);
    final themeNotifier = ref.read(themeViewModelProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Einstellungen'),
      ),
      body: settingsState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Fehler: $err')),
        data: (settings) {
          return ListView(
            children: [
              const SizedBox(height: 16),
              // Profilbereich
              _buildProfileSection(context, ref),
              const SizedBox(height: 8),
              _buildAuthButton(context, ref),
              const SizedBox(height: 8),
              const SizedBox(height: 16),
              const Divider(height: 1),

              // Arbeitszeit
              ListTile(
                title: const Text('Soll-Arbeitsstunden'),
                subtitle: Text(
                  '${settings.weeklyTargetHours.toStringAsFixed(1)} h/Woche\n≈ ${(settings.weeklyTargetHours / 5).toStringAsFixed(1)} h/Tag (bei 5 Arbeitstagen)',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  showEditTargetHoursModal(
                    context,
                    settings.weeklyTargetHours,
                  );
                },
              ),
              const Divider(height: 1),

              // Darstellung
              SwitchListTile(
                title: const Text('Design'),
                subtitle: Text(themeMode == ThemeMode.dark ? 'Dunkel' : 'Hell'),
                value: themeMode == ThemeMode.dark,
                onChanged: (isDark) {
                  themeNotifier.setTheme(isDark ? ThemeMode.dark : ThemeMode.light);
                },
              ),
              const Divider(height: 1),

              // Benachrichtigungen (Beispiel)
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

              // App
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
            ],
          );
        },
      ),
    );
  }

  // Profilbereich mit Avatar und Namen
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

  // Anmelde- oder Abmeldebutton, je nach Anmeldestatus
  Widget _buildAuthButton(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          // Anmeldebutton für nicht angemeldete Benutzer
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
          // Abmeldebutton für angemeldete Benutzer
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: OutlinedButton.icon(
              onPressed: () {
                // Bestätigungsdialog vor dem Abmelden anzeigen
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
