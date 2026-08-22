import 'dart:async';

import 'package:flutter/material.dart';

import 'auth/auth_controller.dart';
import 'auth/auth_scope.dart';
import 'profile/profile_controller.dart';
import 'profile/profile_scope.dart';
import 'screens/auth/firebase_setup_required_screen.dart';
import 'screens/auth/email_verification_screen.dart';
import 'screens/auth/legacy_email_upgrade_screen.dart';
import 'screens/auth/pin_login_screen.dart';
import 'screens/auth/pin_setup_screen.dart';
import 'screens/auth/profile_setup_screen.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/main_navigation.dart';
import 'security/app_lock_controller.dart';
import 'security/app_lock_scope.dart';
import 'services/crash_reporting_service.dart';
import 'services/document_storage_service.dart';
import 'state/app_scope.dart';
import 'state/appliance_store.dart';
import 'theme/app_theme.dart';
import 'widgets/cloud_backup_startup_coordinator.dart';

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

class _HomeVaultAppState extends State<HomeVaultApp>
    with WidgetsBindingObserver {
  late final ApplianceStore _applianceStore;
  late final AppLockController _appLockController;
  AuthController? _authController;
  ProfileController? _profileController;

  late final bool _ownsStore;
  late final bool _ownsLockController;
  late final bool _ownsAuthController;
  late final bool _ownsProfileController;
  String? _profileUserId;
  int _authenticationEpoch = 0;
  Future<void> _authenticationApplyQueue = Future<void>.value();
  bool _hasScheduledAuthenticationState = false;
  String? _lastScheduledAuthenticationUid;
  Timer? _sessionValidationTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ownsStore = widget.applianceStore == null;
    _ownsLockController = widget.appLockController == null;
    _ownsAuthController = widget.authController == null;
    _ownsProfileController = widget.profileController == null;

    _applianceStore = widget.applianceStore ?? ApplianceStore();
    _appLockController = widget.appLockController ?? AppLockController();
    unawaited(_appLockController.initialize());

    if (widget.firebaseInitializationError == null) {
      _authController = widget.authController ?? AuthController();
      _profileController = widget.profileController ?? ProfileController();
      _authController!.addListener(_handleAuthenticationChanged);
      unawaited(_initializeAuthentication());

      _sessionValidationTimer = Timer.periodic(const Duration(minutes: 5), (_) {
        final auth = _authController;
        if (auth?.isAuthenticated == true) {
          unawaited(auth!.validateCurrentSession());
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    final auth = _authController;
    if (auth?.isAuthenticated == true) {
      unawaited(auth!.validateCurrentSession());
    }
  }

  Future<void> _initializeAuthentication() async {
    await _authController!.initialize();
    await _scheduleAuthenticationStateApplyIfNeeded();
  }

  void _handleAuthenticationChanged() {
    unawaited(_scheduleAuthenticationStateApplyIfNeeded());
  }

  Future<void> _scheduleAuthenticationStateApplyIfNeeded() {
    final auth = _authController;
    if (auth == null || auth.isInitializing) {
      return Future<void>.value();
    }

    final uid = auth.user?.uid;
    if (_hasScheduledAuthenticationState &&
        _lastScheduledAuthenticationUid == uid) {
      return Future<void>.value();
    }

    _hasScheduledAuthenticationState = true;
    _lastScheduledAuthenticationUid = uid;
    return _scheduleAuthenticationStateApply();
  }

  Future<void> _scheduleAuthenticationStateApply() {
    _authenticationApplyQueue = _authenticationApplyQueue
        .then((_) => _applyAuthenticationState())
        .catchError((Object error, StackTrace stack) async {
          await CrashReportingService.recordNonFatal(
            error,
            stack,
            reason: 'Applying authenticated HomeVault startup state',
          );
        });
    return _authenticationApplyQueue;
  }

  Future<void> _applyAuthenticationState() async {
    final auth = _authController;
    final profile = _profileController;
    if (auth == null || profile == null || auth.isInitializing) return;

    final epoch = ++_authenticationEpoch;
    final user = auth.user;

    if (user == null) {
      _profileUserId = null;
      profile.clear();
      await Future.wait([
        _appLockController.bindUser(null),
        _applianceStore.bindOwner(null),
        DocumentStorageService.bindOwner(null),
        CrashReportingService.setAuthenticatedUser(null),
      ]);
      return;
    }

    await Future.wait([
      _appLockController.bindUser(user.uid),
      _applianceStore.bindOwner(user.uid),
      DocumentStorageService.bindOwner(user.uid),
      CrashReportingService.setAuthenticatedUser(user.uid),
    ]);

    if (auth.consumeAccountSignInUnlock()) {
      _appLockController.unlockAfterAccountAuthentication();
    }

    if (epoch != _authenticationEpoch || auth.user?.uid != user.uid) return;

    if (_profileUserId != user.uid) {
      _profileUserId = user.uid;
      await profile.loadForUser(user);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionValidationTimer?.cancel();
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
    // Initial authentication/session validation must finish before the app
    // is shown. Later validation (for example immediately before PIN or
    // biometric unlock) must not replace and dispose the unlock screen while
    // that unlock operation is awaiting Firebase.
    if (auth.isInitializing) {
      return const _LoadingScreen(message: 'Checking your account...');
    }

    if (!auth.isAuthenticated) {
      return const WelcomeScreen();
    }

    if (auth.needsLegacyEmailUpgrade) {
      return const LegacyEmailUpgradeScreen();
    }

    if (!auth.isEmailVerified) {
      return const EmailVerificationScreen();
    }

    final lockController = AppLockScope.of(context);
    if (lockController.isInitializing ||
        lockController.boundUid != auth.user?.uid) {
      return const _LoadingScreen(message: 'Securing HomeVault...');
    }

    if (!lockController.hasPin) {
      return const PinSetupScreen(allowSkip: false);
    }

    final profile = ProfileScope.of(context);
    final authenticatedUid = auth.user?.uid;

    if (authenticatedUid == null ||
        !profile.isResolvedForUser(authenticatedUid)) {
      return const _LoadingScreen(message: 'Loading your profile...');
    }

    if (profile.errorMessage != null) {
      return _ProfileLoadErrorScreen(message: profile.errorMessage!);
    }

    if (!profile.hasCompleteProfile) {
      return const ProfileSetupScreen();
    }

    if (!lockController.isUnlocked) {
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
    final uid = AuthScope.of(context).user?.uid;

    final initialLoadPending = !store.isInitialized && store.loadError == null;

    if (store.ownerUid != uid || initialLoadPending) {
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

    return const CloudBackupStartupCoordinator(child: MainNavigation());
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
