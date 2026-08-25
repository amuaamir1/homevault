import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/appliance.dart';
import '../../models/support_directory_entry.dart';
import '../../services/homevault_error_presenter.dart';
import '../../services/support_action_service.dart';

class ProviderDetailsScreen extends StatelessWidget {
  const ProviderDetailsScreen({
    super.key,
    required this.entry,
    required this.appliances,
    required this.onRequestService,
    required this.onEditAppliance,
  });

  final SupportDirectoryEntry entry;
  final List<Appliance> appliances;
  final Future<void> Function() onRequestService;
  final Future<void> Function(Appliance appliance) onEditAppliance;

  Future<void> _runAction(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (error) {
      if (!context.mounted) return;
      showHomeVaultError(
        context,
        error,
        fallback: 'The provider action could not be opened. Please try again.',
      );
    }
  }

  Future<void> _copy(BuildContext context, String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label copied.')));
  }

  @override
  Widget build(BuildContext context) {
    final actionService = const SupportActionService();
    final linkedAppliances =
        appliances
            .where((appliance) => entry.applianceIds.contains(appliance.id))
            .toList(growable: false)
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

    return Scaffold(
      appBar: AppBar(title: const Text('Provider details')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 25,
                        child: Text(
                          entry.name.isEmpty
                              ? '?'
                              : entry.name[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.name,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: entry.roles
                                  .map(
                                    (role) => Chip(
                                      visualDensity: VisualDensity.compact,
                                      label: Text(role.label),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (entry.hasPhone)
                        FilledButton.tonalIcon(
                          onPressed: () => _runAction(
                            context,
                            () => actionService.call(entry.primaryPhone),
                          ),
                          icon: const Icon(Icons.phone_outlined),
                          label: const Text('Call'),
                        ),
                      if (entry.hasEmail)
                        FilledButton.tonalIcon(
                          onPressed: () => _runAction(
                            context,
                            () => actionService.emailProvider(
                              email: entry.primaryEmail,
                              providerName: entry.name,
                            ),
                          ),
                          icon: const Icon(Icons.email_outlined),
                          label: const Text('Email'),
                        ),
                      if (entry.hasWebsite)
                        FilledButton.tonalIcon(
                          onPressed: () => _runAction(
                            context,
                            () =>
                                actionService.openWebsite(entry.primaryWebsite),
                          ),
                          icon: const Icon(Icons.language),
                          label: const Text('Website'),
                        ),
                      if (linkedAppliances.isNotEmpty)
                        FilledButton.icon(
                          key: const Key('providerRequestServiceButton'),
                          onPressed: onRequestService,
                          icon: const Icon(Icons.build_outlined),
                          label: const Text('Request service'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Contact details',
            child: entry.hasAnyContact
                ? Column(
                    children: [
                      for (final phone in entry.phones)
                        _ContactRow(
                          icon: Icons.phone_outlined,
                          label: 'Phone',
                          value: phone,
                          onCopy: () => _copy(context, 'Phone', phone),
                        ),
                      for (final email in entry.emails)
                        _ContactRow(
                          icon: Icons.email_outlined,
                          label: 'Email',
                          value: email,
                          onCopy: () => _copy(context, 'Email', email),
                        ),
                      for (final website in entry.websites)
                        _ContactRow(
                          icon: Icons.language,
                          label: 'Website',
                          value: website,
                          onCopy: () => _copy(context, 'Website', website),
                        ),
                    ],
                  )
                : const Text(
                    'No phone, email, or website is saved yet. Add support details to a linked appliance to complete this provider profile.',
                  ),
          ),
          if (entry.serviceLocations.isNotEmpty) ...[
            const SizedBox(height: 16),
            _Section(
              title: 'Service locations used',
              child: Column(
                children: entry.serviceLocations
                    .map(
                      (location) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.location_on_outlined),
                        title: Text(location),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _Section(
            title: 'Linked appliances',
            child: linkedAppliances.isEmpty
                ? const Text(
                    'No appliance is currently linked to this provider.',
                  )
                : Column(
                    children: linkedAppliances
                        .map(
                          (appliance) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.devices_other_outlined),
                            title: Text(appliance.name),
                            subtitle: Text(
                              [appliance.brand, appliance.category]
                                  .where((value) => value.trim().isNotEmpty)
                                  .join(' • '),
                            ),
                            trailing: IconButton(
                              tooltip:
                                  'Edit support details for ${appliance.name}',
                              onPressed: () => onEditAppliance(appliance),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
          ),
          if (entry.notes.isNotEmpty) ...[
            const SizedBox(height: 16),
            _Section(
              title: 'Saved notes',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: entry.notes
                    .map(
                      (note) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(note),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Provider details are built from information saved in your appliances, AMC/warranty records, and service requests. HomeVault does not independently verify these contact details.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onCopy,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(value),
      trailing: IconButton(
        tooltip: 'Copy ${label.toLowerCase()}',
        onPressed: onCopy,
        icon: const Icon(Icons.copy_outlined),
      ),
    );
  }
}
