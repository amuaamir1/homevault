import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/homevault_legal_links.dart';
import 'account_deletion_screen.dart';

class AccountDataDeletionInfoScreen extends StatelessWidget {
  const AccountDataDeletionInfoScreen({super.key});

  Future<void> _openWebDeletionPage(BuildContext context) async {
    final uri = HomeVaultLegalLinks.accountDeletionUri;
    if (uri == null) {
      await _showMessage(
        context,
        title: 'Web deletion page not configured yet',
        message:
            'The public HomeVault account-deletion webpage will be added '
            'before the Google Play production release. You can already '
            'delete your account directly inside HomeVault.',
      );
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      await _showMessage(
        context,
        title: 'Could not open webpage',
        message:
            'HomeVault could not open the account-deletion webpage on your '
            'device. Please try again.',
      );
    }
  }

  Future<void> _showMessage(
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
      appBar: AppBar(title: const Text('Account & Data Deletion')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.delete_forever_outlined,
                    size: 36,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Delete your HomeVault account',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'HomeVault provides an in-app account deletion flow that '
                    'removes your HomeVault account and associated HomeVault '
                    'data. Account deletion is permanent and cannot be undone.',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'In-app path: Settings → Account & Data → Delete account',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey('deleteAccountInAppButton'),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const AccountDeletionScreen(),
                ),
              );
            },
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('Delete account in HomeVault'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const ValueKey('openWebDeletionPageButton'),
            onPressed: () => _openWebDeletionPage(context),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open account deletion webpage'),
          ),
          const SizedBox(height: 12),
          Text(
            'The public webpage is provided for users who no longer have '
            'access to the HomeVault app.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
