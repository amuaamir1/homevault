import 'package:flutter/material.dart';

import 'screens/main_navigation.dart';
import 'state/app_scope.dart';
import 'state/appliance_store.dart';
import 'theme/app_theme.dart';

class HomeVaultApp extends StatefulWidget {
  const HomeVaultApp({super.key});

  @override
  State<HomeVaultApp> createState() => _HomeVaultAppState();
}

class _HomeVaultAppState extends State<HomeVaultApp> {
  late final ApplianceStore _applianceStore;

  @override
  void initState() {
    super.initState();
    _applianceStore = ApplianceStore();
  }

  @override
  void dispose() {
    _applianceStore.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      applianceStore: _applianceStore,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'HomeVault',
        theme: AppTheme.lightTheme,
        home: const MainNavigation(),
      ),
    );
  }
}
