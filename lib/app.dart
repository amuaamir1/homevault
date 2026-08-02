import 'package:flutter/material.dart';

import 'screens/auth/pin_login_screen.dart';
import 'screens/auth/pin_setup_screen.dart';
import 'screens/main_navigation.dart';
import 'security/app_lock_controller.dart';
import 'security/app_lock_scope.dart';
import 'state/app_scope.dart';
import 'state/appliance_store.dart';
import 'theme/app_theme.dart';

class HomeVaultApp extends StatefulWidget {
  const HomeVaultApp({super.key, this.applianceStore, this.appLockController});

  final ApplianceStore? applianceStore;
  final AppLockController? appLockController;

  @override
  State<HomeVaultApp> createState() => _HomeVaultAppState();
}

class _HomeVaultAppState extends State<HomeVaultApp> {
  late final ApplianceStore _applianceStore;
  late final AppLockController _appLockController;
  late final bool _ownsStore;
  late final bool _ownsLockController;

  @override
  void initState() {
    super.initState();
    _ownsStore = widget.applianceStore == null;
    _ownsLockController = widget.appLockController == null;
    _applianceStore = widget.applianceStore ?? ApplianceStore();
    _appLockController = widget.appLockController ?? AppLockController();

    _applianceStore.initialize();
    _appLockController.initialize();
  }

  @override
  void dispose() {
    if (_ownsStore) {
      _applianceStore.dispose();
    }
    if (_ownsLockController) {
      _appLockController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      applianceStore: _applianceStore,
      child: AppLockScope(
        controller: _appLockController,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'HomeVault',
          theme: AppTheme.lightTheme,
          home: const _AppGate(),
        ),
      ),
    );
  }
}

class _AppGate extends StatelessWidget {
  const _AppGate();

  @override
  Widget build(BuildContext context) {
    final lockController = AppLockScope.of(context);

    if (lockController.isInitializing) {
      return const _LoadingScreen(message: 'Securing HomeVault...');
    }

    if (!lockController.hasPin) {
      return const PinSetupScreen();
    }

    if (!lockController.isUnlocked) {
      return const PinLoginScreen();
    }

    return const _StartupGate();
  }
}

class _StartupGate extends StatelessWidget {
  const _StartupGate();

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);

    if (store.isLoading) {
      return const _LoadingScreen(message: 'Loading your HomeVault...');
    }

    if (store.loadError != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.storage_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your saved data could not be loaded',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(store.loadError!, textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => store.initialize(force: true),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return const MainNavigation();
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      ),
    );
  }
}
