import 'package:flutter/material.dart';

import 'screens/main_navigation.dart';
import 'state/app_scope.dart';
import 'state/appliance_store.dart';
import 'theme/app_theme.dart';

class HomeVaultApp extends StatefulWidget {
  const HomeVaultApp({super.key, this.applianceStore});

  final ApplianceStore? applianceStore;

  @override
  State<HomeVaultApp> createState() => _HomeVaultAppState();
}

class _HomeVaultAppState extends State<HomeVaultApp> {
  late final ApplianceStore _applianceStore;
  late final bool _ownsStore;

  @override
  void initState() {
    super.initState();
    _ownsStore = widget.applianceStore == null;
    _applianceStore = widget.applianceStore ?? ApplianceStore();
    _applianceStore.initialize();
  }

  @override
  void dispose() {
    if (_ownsStore) {
      _applianceStore.dispose();
    }
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
        home: const _StartupGate(),
      ),
    );
  }
}

class _StartupGate extends StatelessWidget {
  const _StartupGate();

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);

    if (store.isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading your HomeVault...'),
            ],
          ),
        ),
      );
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
