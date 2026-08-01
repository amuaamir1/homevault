import 'dart:async';

import 'package:flutter/material.dart';

import '../models/appliance_form_result.dart';
import '../services/document_storage_service.dart';
import '../services/warranty_notification_service.dart';
import '../state/app_scope.dart';
import 'appliances/add_appliance_screen.dart';
import 'appliances/appliance_details_screen.dart';
import 'appliances/appliances_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'documents/documents_screen.dart';
import 'settings/settings_screen.dart';
import 'support/support_screen.dart';
import 'warranty/warranty_screen.dart';
import '../models/app_section.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  AppSection _selectedSection = AppSection.home;
  StreamSubscription<String>? _notificationTapSubscription;

  @override
  void initState() {
    super.initState();
    final notificationService = WarrantyNotificationService.instance;
    _notificationTapSubscription = notificationService.notificationTaps.listen(
      _openApplianceFromReminder,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final applianceId = notificationService.takePendingApplianceId();
      if (applianceId != null) {
        _openApplianceFromReminder(applianceId);
      }
    });
  }

  @override
  void dispose() {
    _notificationTapSubscription?.cancel();
    super.dispose();
  }

  void _openApplianceFromReminder(String applianceId) {
    if (!mounted || AppScope.read(context).applianceById(applianceId) == null) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ApplianceDetailsScreen(applianceId: applianceId),
      ),
    );
  }

  void _goToSection(AppSection section) {
    setState(() => _selectedSection = section);
  }

  Future<void> _openAddAppliance() async {
    final result = await Navigator.of(context).push<ApplianceFormResult>(
      MaterialPageRoute(builder: (context) => const AddApplianceScreen()),
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
        await DocumentStorageService().deleteApplianceDocuments(
          result.appliance.id,
        );
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

  Future<void> _openWarrantyCenter(WarrantyFilter initialFilter) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => WarrantyScreen(initialFilter: initialFilter),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      DashboardScreen(
        onNavigate: _goToSection,
        onAddAppliance: _openAddAppliance,
        onOpenWarrantyCenter: _openWarrantyCenter,
      ),
      AppliancesScreen(onAddAppliance: _openAddAppliance),
      const DocumentsScreen(),
      const SupportScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedSection.index, children: screens),
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
