import 'package:flutter/material.dart';

import '../models/appliance_form_result.dart';
import '../services/document_storage_service.dart';
import '../state/app_scope.dart';
import 'appliances/add_appliance_screen.dart';
import 'appliances/appliances_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'documents/documents_screen.dart';
import 'settings/settings_screen.dart';
import 'support/support_screen.dart';

enum AppSection {
  home,
  appliances,
  documents,
  support,
  settings,
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  AppSection _selectedSection = AppSection.home;

  void _goToSection(AppSection section) {
    setState(() => _selectedSection = section);
  }

  Future<void> _openAddAppliance() async {
    final result = await Navigator.of(context).push<ApplianceFormResult>(
      MaterialPageRoute(
        builder: (context) => const AddApplianceScreen(),
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    try {
      await AppScope.read(context).add(result.appliance);
      if (!mounted) return;

      setState(() => _selectedSection = AppSection.appliances);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.appliance.name} was saved.')),
      );
    } catch (_) {
      try {
        await DocumentStorageService()
            .deleteApplianceDocuments(result.appliance.id);
      } catch (_) {
        // A failed cleanup should not hide the original save error.
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The appliance could not be saved. Please check the device storage and try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      DashboardScreen(
        onNavigate: _goToSection,
        onAddAppliance: _openAddAppliance,
      ),
      AppliancesScreen(onAddAppliance: _openAddAppliance),
      const DocumentsScreen(),
      const SupportScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedSection.index,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedSection.index,
        onDestinationSelected: (index) {
          _goToSection(AppSection.values[index]);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.home_repair_service_outlined),
            selectedIcon: Icon(Icons.home_repair_service),
            label: 'Appliances',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Documents',
          ),
          NavigationDestination(
            icon: Icon(Icons.support_agent_outlined),
            selectedIcon: Icon(Icons.support_agent),
            label: 'Support',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
