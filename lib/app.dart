import 'package:flutter/material.dart';

import 'auth/auth_controller.dart';
import 'auth/auth_scope.dart';
import 'profile/profile_controller.dart';
import 'profile/profile_scope.dart';
import 'screens/auth/firebase_setup_required_screen.dart';
import 'screens/auth/mobile_login_screen.dart';
import 'screens/auth/otp_verification_screen.dart';
import 'screens/auth/pin_login_screen.dart';
import 'screens/auth/pin_setup_screen.dart';
import 'screens/auth/profile_setup_screen.dart';
import 'screens/main_navigation.dart';
import 'security/app_lock_controller.dart';
import 'security/app_lock_scope.dart';
import 'state/app_scope.dart';
import 'state/appliance_store.dart';
import 'theme/app_theme.dart';

class HomeVaultApp extends StatefulWidget {
  const HomeVaultApp({
    super.key,
    this.applianceStore,
    this.appLockController,
    this.authController,
    this.profileController,
    this.firebaseInitializationError,
  });

  final ApplianceStore? applianceStore;
  final AppLockController? appLockController;
  final AuthController? authController;
  final ProfileController? profileController;
  final Object? firebaseInitializationError;

  @override
  State<HomeVaultApp> createState() => _HomeVaultAppState();
}

class _HomeVaultAppState extends State<HomeVaultApp> {
  late final ApplianceStore _applianceStore;
  late final AppLockController _appLockController;
  AuthController? _authController;
  ProfileController? _profileController;

  late final bool _ownsStore;
  late final bool _ownsLockController;
  late final bool _ownsAuthController;
  late final bool _ownsProfileController;
  String? _profileUserId;

  @override
  void initState() {
    super.initState();
    _ownsStore = widget.applianceStore == null;
    _ownsLockController = widget.appLockController == null;
    _ownsAuthController = widget.authController == null;
    _ownsProfileController = widget.profileController == null;

    _applianceStore = widget.applianceStore ?? ApplianceStore();
    _appLockController = widget.appLockController ?? AppLockController();

    if (widget.firebaseInitializationError == null) {
      _authController = widget.authController ?? AuthController();
      _profileController = widget.profileController ?? ProfileController();
      _authController!.addListener(_handleAuthenticationChanged);
      _authController!.initialize();
    }

    _applianceStore.initialize();
    _appLockController.initialize();
  }

  void _handleAuthenticationChanged() {
    final auth = _authController;
    final profile = _profileController;
    if (auth == null || profile == null || auth.isInitializing) return;

    final user = auth.user;
    if (user == null) {
      if (_profileUserId != null) {
        _profileUserId = null;
        profile.clear();
      }
      return;
    }

    if (_profileUserId == user.uid) return;
    _profileUserId = user.uid;
    profile.loadForUser(user);
  }

  @override
  void dispose() {
    _authController?.removeListener(_handleAuthenticationChanged);
    if (_ownsStore) _applianceStore.dispose();
    if (_ownsLockController) _appLockController.dispose();
    if (_ownsAuthController) _authController?.dispose();
    if (_ownsProfileController) _profileController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authController = _authController;
    final profileController = _profileController;

    Widget app = MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HomeVault',
      theme: AppTheme.lightTheme,
      home: _AppGate(
        firebaseInitializationError: widget.firebaseInitializationError,
      ),
    );

    app = AppScope(applianceStore: _applianceStore, child: app);
    app = AppLockScope(controller: _appLockController, child: app);

    if (authController != null && profileController != null) {
      app = ProfileScope(controller: profileController, child: app);
      app = AuthScope(controller: authController, child: app);
    }

    return app;
  }
}

class _AppGate extends StatelessWidget {
  const _AppGate({this.firebaseInitializationError});

  final Object? firebaseInitializationError;

  @override
  Widget build(BuildContext context) {
    if (firebaseInitializationError != null) {
      return FirebaseSetupRequiredScreen(details: firebaseInitializationError);
    }

    final auth = AuthScope.of(context);
    if (auth.isInitializing) {
      return const _LoadingScreen(message: 'Checking your account...');
    }

    if (!auth.isAuthenticated) {
      return auth.isAwaitingOtp
          ? const OtpVerificationScreen()
          : const MobileLoginScreen();
    }

    final profile = ProfileScope.of(context);
    if (profile.isLoading) {
      return const _LoadingScreen(message: 'Loading your profile...');
    }

    if (profile.errorMessage != null) {
      return _ProfileLoadErrorScreen(message: profile.errorMessage!);
    }

    if (!profile.hasCompleteProfile) {
      return const ProfileSetupScreen();
    }

    final lockController = AppLockScope.of(context);
    if (lockController.isInitializing) {
      return const _LoadingScreen(message: 'Securing HomeVault...');
    }

    if (!lockController.pinSetupCompleted) {
      return const PinSetupScreen(allowSkip: true);
    }

    if (lockController.hasPin && !lockController.isUnlocked) {
      return const PinLoginScreen();
    }

    return const _StartupGate();
  }
}

class _ProfileLoadErrorScreen extends StatelessWidget {
  const _ProfileLoadErrorScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Your profile could not be loaded',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () {
                    final user = auth.user;
                    if (user != null) {
                      ProfileScope.read(context).loadForUser(user, force: true);
                    }
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
                TextButton(
                  onPressed: auth.signOut,
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
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
