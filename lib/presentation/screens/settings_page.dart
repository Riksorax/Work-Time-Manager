import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../view_models/settings_view_model.dart';
import '../view_models/theme_view_model.dart';
import '../widgets/edit_target_hours_modal.dart';

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
              // Profile Section (Beispiel)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 30,
                      child: Icon(Icons.person, size: 30),
                    ),
                    const SizedBox(width: 16),
                    Text('Max Mustermann', style: theme.textTheme.titleLarge),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),

              // Arbeitszeit
              ListTile(
                title: const Text('Soll-Arbeitsstunden'),
                subtitle: Text('${settings.weeklyTargetHours.toStringAsFixed(1)} Stunden pro Woche'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  showEditTargetHoursModal(
                    context,
                    settings.weeklyTargetHours.toInt(),
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
}
