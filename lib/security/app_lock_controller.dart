import 'package:flutter/widgets.dart';

import 'auto_lock_preference_service.dart';
import 'biometric_security_service.dart';
import 'pin_security_service.dart';

class AppLockController extends ChangeNotifier with WidgetsBindingObserver {
  AppLockController({
    PinSecurityService? securityService,
    BiometricSecurityService? biometricService,
    AutoLockPreferenceService? autoLockPreferenceService,
    Duration lockAfter = const Duration(minutes: 2),
  }) : _securityService = securityService ?? PinSecurityService(),
       _biometricService = biometricService ?? BiometricSecurityService(),
       _autoLockPreferenceService =
           autoLockPreferenceService ?? AutoLockPreferenceService(),
       _lockAfter = lockAfter;

  AppLockController.unlockedForTesting({String uid = 'test-user'})
    : _securityService = PinSecurityService(),
      _biometricService = BiometricSecurityService(),
      _autoLockPreferenceService = AutoLockPreferenceService(),
      _lockAfter = Duration.zero,
      _isInitializing = false,
      _pinSetupCompleted = true,
      _hasPin = true,
      _isUnlocked = true,
      _boundUid = uid,
      _isTestBypass = true;

  final PinSecurityService _securityService;
  final BiometricSecurityService _biometricService;
  final AutoLockPreferenceService _autoLockPreferenceService;

  Duration _lockAfter;
  AutoLockOption _autoLockOption = AutoLockOption.twoMinutes;
  String? _boundUid;

  bool _isInitializing = true;
  bool _pinSetupCompleted = false;
  bool _hasPin = false;
  bool _isUnlocked = false;
  bool _isDisposed = false;
  bool _isTestBypass = false;
  bool _observerRegistered = false;
  bool _isBiometricAvailable = false;
  bool _isBiometricEnabled = false;
  bool _isAuthenticatingBiometric = false;
  String _biometricLabel = 'biometric unlock';
  String? _biometricErrorMessage;
  DateTime? _backgroundedAt;

  bool get isInitializing => _isInitializing;
  bool get pinSetupCompleted => _pinSetupCompleted;
  bool get hasPin => _hasPin;
  bool get isUnlocked => _isUnlocked;
  bool get isBiometricAvailable => _isBiometricAvailable;
  bool get isBiometricEnabled => _isBiometricEnabled;
  bool get isAuthenticatingBiometric => _isAuthenticatingBiometric;
  String get biometricLabel => _biometricLabel;
  String? get biometricErrorMessage => _biometricErrorMessage;
  Duration get lockAfter => _lockAfter;
  AutoLockOption get autoLockOption => _autoLockOption;
  String? get boundUid => _boundUid;

  Future<void> initialize() async {
    if (_isTestBypass) return;

    if (!_observerRegistered) {
      WidgetsBinding.instance.addObserver(this);
      _observerRegistered = true;
    }

    _isInitializing = false;
    _notifySafely();
  }

  Future<void> bindUser(String? uid) async {
    if (_isTestBypass) return;
    if (uid == _boundUid && !_isInitializing) return;

    if (uid == null || uid.trim().isEmpty) {
      _boundUid = null;
      _pinSetupCompleted = false;
      _hasPin = false;
      _isUnlocked = false;
      _isBiometricEnabled = false;
      _isBiometricAvailable = false;
      _biometricErrorMessage = null;
      _backgroundedAt = null;
      _isInitializing = false;
      _notifySafely();
      return;
    }

    _isInitializing = true;
    _isUnlocked = false;
    _notifySafely();

    try {
      _boundUid = uid;
      await _securityService.bindUser(uid);
      await _biometricService.bindUser(uid);
      _autoLockPreferenceService.bindUser(uid);

      _autoLockOption = await _autoLockPreferenceService.load();
      _lockAfter = _autoLockOption.duration;
      _hasPin = await _securityService.hasPin();
      _pinSetupCompleted =
          _hasPin || await _securityService.hasCompletedPinSetup();
      _isUnlocked = !_hasPin;
      await _loadBiometricState();
    } finally {
      _isInitializing = false;
      _notifySafely();
    }
  }

  Future<void> setAutoLockOption(AutoLockOption option) async {
    if (_boundUid == null) return;
    await _autoLockPreferenceService.save(option);
    _autoLockOption = option;
    _lockAfter = option.duration;
    _notifySafely();
  }

  Future<void> createPin(String pin) async {
    await _securityService.createPin(pin);
    _pinSetupCompleted = true;
    _hasPin = true;
    _isUnlocked = true;
    _biometricErrorMessage = null;
    await _loadBiometricState();
    _notifySafely();
  }

  Future<void> skipPinSetup() async {
    await _securityService.markPinSetupSkipped();
    _pinSetupCompleted = true;
    _hasPin = false;
    _isUnlocked = true;
    await _biometricService.setEnabled(false);
    _isBiometricEnabled = false;
    _notifySafely();
  }

  Future<bool> unlock(String pin) async {
    final isValid = await _securityService.verifyPin(pin);
    if (isValid) {
      _isUnlocked = true;
      _backgroundedAt = null;
      _biometricErrorMessage = null;
      _notifySafely();
    }
    return isValid;
  }

  Future<bool> authenticateWithBiometrics() async {
    if (!_hasPin ||
        !_isBiometricEnabled ||
        !_isBiometricAvailable ||
        _isAuthenticatingBiometric) {
      return false;
    }

    _isAuthenticatingBiometric = true;
    _biometricErrorMessage = null;
    _notifySafely();

    final result = await _biometricService.authenticate();

    _isAuthenticatingBiometric = false;
    if (result.authenticated) {
      _isUnlocked = true;
      _backgroundedAt = null;
      _biometricErrorMessage = null;
    } else if (!result.wasCanceled) {
      _biometricErrorMessage = result.message;
    }
    _notifySafely();
    return result.authenticated;
  }

  Future<bool> setBiometricEnabled(bool enabled) async {
    _biometricErrorMessage = null;

    if (!enabled) {
      await _biometricService.setEnabled(false);
      _isBiometricEnabled = false;
      _notifySafely();
      return true;
    }

    if (!_hasPin) {
      _biometricErrorMessage =
          'Create a HomeVault PIN before enabling biometric unlock.';
      _notifySafely();
      return false;
    }

    await _loadBiometricState();
    if (!_isBiometricAvailable) {
      _notifySafely();
      return false;
    }

    final result = await _biometricService.authenticate();
    if (!result.authenticated) {
      if (!result.wasCanceled) {
        _biometricErrorMessage = result.message;
      }
      _notifySafely();
      return false;
    }

    await _biometricService.setEnabled(true);
    _isBiometricEnabled = true;
    _biometricErrorMessage = null;
    _notifySafely();
    return true;
  }

  Future<void> refreshBiometricState() async {
    if (_boundUid == null) return;
    await _loadBiometricState();
    _notifySafely();
  }

  Future<bool> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    final changed = await _securityService.changePin(
      currentPin: currentPin,
      newPin: newPin,
    );

    if (changed) {
      _pinSetupCompleted = true;
      _hasPin = true;
      _isUnlocked = true;
      _notifySafely();
    }
    return changed;
  }

  Future<void> removePin() async {
    await _securityService.clearPin();
    await _biometricService.setEnabled(false);
    _pinSetupCompleted = true;
    _hasPin = false;
    _isUnlocked = true;
    _isBiometricEnabled = false;
    _backgroundedAt = null;
    _notifySafely();
  }

  /// Locks the current in-memory session before Firebase sign-out without
  /// deleting the account-scoped PIN or biometric preference.
  void prepareForSignOut() {
    _isUnlocked = false;
    _backgroundedAt = null;
    _biometricErrorMessage = null;
    _notifySafely();
  }

  Future<void> resetPinForOtpRecovery() async {
    await _securityService.clearPin(markSetupComplete: false);
    await _biometricService.setEnabled(false);
    _pinSetupCompleted = false;
    _hasPin = false;
    _isUnlocked = true;
    _isBiometricEnabled = false;
    _biometricErrorMessage = null;
    _backgroundedAt = null;
    _notifySafely();
  }

  void lock() {
    if (!_hasPin || !_isUnlocked) return;
    _isUnlocked = false;
    _notifySafely();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _backgroundedAt ??= DateTime.now();
        break;
      case AppLifecycleState.resumed:
        final backgroundedAt = _backgroundedAt;
        _backgroundedAt = null;
        if (backgroundedAt != null &&
            DateTime.now().difference(backgroundedAt) >= _lockAfter) {
          lock();
        }
        break;
      case AppLifecycleState.detached:
        lock();
        break;
    }
  }

  Future<void> _loadBiometricState() async {
    final status = await _biometricService.getDeviceStatus();
    _isBiometricAvailable = status.isAvailable;
    _biometricLabel = status.label;
    _biometricErrorMessage = status.isAvailable ? null : status.message;

    final preferenceEnabled = await _biometricService.isEnabled();
    _isBiometricEnabled = _hasPin && preferenceEnabled;

    if (!_hasPin && preferenceEnabled) {
      await _biometricService.setEnabled(false);
      _isBiometricEnabled = false;
    }
  }

  void _notifySafely() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    if (_observerRegistered) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }
}
