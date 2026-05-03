import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers/providers.dart' as core_providers;
import '../widgets/imprint_dialog.dart';
import '../widgets/privacy_policy_dialog.dart';
import '../widgets/terms_of_service_dialog.dart';
import '../widgets/update_required_dialog.dart';

class AppInfoPage extends ConsumerWidget {
  const AppInfoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Über die App'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          _buildAppIcon(context),
          const SizedBox(height: 16),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final version = snapshot.data?.version ?? '...';
              final buildNumber = snapshot.data?.buildNumber ?? '';
              return Column(
                children: [
                  Text(
                    'Work Time Manager',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Version $version ($buildNumber)',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 32),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.shop, color: Colors.green),
            title: const Text('App im Google Play Store bewerten'),
            subtitle: const Text('Unterstützen Sie uns mit einer Bewertung'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () async {
              final url = Uri.parse(
                'https://play.google.com/store/apps/details?id=app.work_time_manager',
              );
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
          ),
          if (kDebugMode) ...[
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.bug_report, color: Colors.orange),
              title: const Text('🧪 TEST: Version Check'),
              subtitle: const Text('Update-Dialog manuell anzeigen'),
              onTap: () async {
                final versionService = ref.read(core_providers.versionServiceProvider);
                await UpdateRequiredDialog.checkAndShow(context, versionService);
              },
            ),
          ],
          const Divider(height: 1),
          ListTile(
            title: const Text('Impressum'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => ImprintDialog.show(context),
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('Allgemeine Geschäftsbedingungen'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => TermsOfServiceDialog.show(context),
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('Datenschutzerklärung'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => PrivacyPolicyDialog.show(context),
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }

  Widget _buildAppIcon(BuildContext context) {
    return Center(
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          image: const DecorationImage(
            image: AssetImage('assets/icon/WorkTimeManagerLogo.png'),
            fit: BoxFit.cover,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      ),
    );
  }
}
