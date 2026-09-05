import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_build_info.dart';
import '../../core/homevault_legal_links.dart';
import 'account_data_deletion_info_screen.dart';

class AboutLegalScreen extends StatelessWidget {
  const AboutLegalScreen({super.key});

  Future<void> _openExternalLink(
    BuildContext context, {
    required Uri? uri,
    required String unavailableTitle,
    required String unavailableMessage,
  }) async {
    if (uri == null) {
      await _showUnavailable(
        context,
        title: unavailableTitle,
        message: unavailableMessage,
      );
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      await _showUnavailable(
        context,
        title: 'Could not open link',
        message:
            'HomeVault could not open this link on your device. Please try again.',
      );
    }
  }

  Future<void> _showUnavailable(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About & Legal')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  key: const ValueKey('aboutLegalPrivacyPolicyTile'),
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy Policy'),
                  subtitle: const Text(
                    'Learn how HomeVault handles and protects your data.',
                  ),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => _openExternalLink(
                    context,
                    uri: HomeVaultLegalLinks.privacyPolicyUri,
                    unavailableTitle: 'Privacy Policy not configured yet',
                    unavailableMessage:
                        'The public HomeVault Privacy Policy URL will be added '
                        'before the Google Play production release.',
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const ValueKey('aboutLegalTermsTile'),
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Terms of Service'),
                  subtitle: const Text(
                    'Read the terms that apply when using HomeVault.',
                  ),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => _openExternalLink(
                    context,
                    uri: HomeVaultLegalLinks.termsOfServiceUri,
                    unavailableTitle: 'Terms of Service not configured yet',
                    unavailableMessage:
                        'The public HomeVault Terms of Service URL will be '
                        'added before the Google Play production release.',
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const ValueKey('aboutLegalAccountDeletionTile'),
                  leading: const Icon(Icons.delete_forever_outlined),
                  title: const Text('Account & Data Deletion'),
                  subtitle: const Text(
                    'Delete your HomeVault account and associated data.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) =>
                            const AccountDataDeletionInfoScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  key: const ValueKey('aboutLegalSupportTile'),
                  leading: const Icon(Icons.support_agent_outlined),
                  title: const Text('Contact Support'),
                  subtitle: const Text(
                    'Get help with HomeVault or contact the support team.',
                  ),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => _openExternalLink(
                    context,
                    uri: HomeVaultLegalLinks.supportEmailUri,
                    unavailableTitle: 'Support email not configured yet',
                    unavailableMessage:
                        'The public HomeVault support email will be added '
                        'before the Google Play production release.',
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const ValueKey('aboutLegalLicensesTile'),
                  leading: const Icon(Icons.code_outlined),
                  title: const Text('Open-source licenses'),
                  subtitle: const Text(
                    'View licenses for software used by HomeVault.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    showLicensePage(
                      context: context,
                      applicationName: 'HomeVault',
                      applicationVersion:
                          '${AppBuildInfo.version}+${AppBuildInfo.buildNumber}',
                      applicationLegalese:
                          'HomeVault uses open-source software packages.',
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HomeVault',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Version ${AppBuildInfo.version} '
                    '(${AppBuildInfo.buildNumber})',
                    key: const ValueKey('aboutLegalVersionText'),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Release ${AppBuildInfo.releaseNumber}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
