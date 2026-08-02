import 'package:flutter/widgets.dart';

import 'pin_security_service.dart';

class AppLockController extends ChangeNotifier with WidgetsBindingObserver {
  AppLockController({
    PinSecurityService? securityService,
    this.lockAfter = const Duration(minutes: 2),
  }) : _securityService = securityService ?? PinSecurityService();

  AppLockController.unlockedForTesting()
    : _securityService = PinSecurityService(),
      lockAfter = Duration.zero,
      _isInitializing = false,
      _pinSetupCompleted = true,
      _hasPin = true,
      _isUnlocked = true,
      _isTestBypass = true;

  final PinSecurityService _securityService;
  final Duration lockAfter;

  bool _isInitializing = true;
  bool _pinSetupCompleted = false;
  bool _hasPin = false;
  bool _isUnlocked = false;
  bool _isDisposed = false;
  bool _isTestBypass = false;
  DateTime? _backgroundedAt;

  bool get isInitializing => _isInitializing;
  bool get pinSetupCompleted => _pinSetupCompleted;
  bool get hasPin => _hasPin;
  bool get isUnlocked => _isUnlocked;

  Future<void> initialize() async {
    if (_isTestBypass) return;

    WidgetsBinding.instance.addObserver(this);
    try {
      _hasPin = await _securityService.hasPin();
      _pinSetupCompleted =
          _hasPin || await _securityService.hasCompletedPinSetup();
      _isUnlocked = !_hasPin;
    } finally {
      _isInitializing = false;
      _notifySafely();
    }
  }

  Future<void> createPin(String pin) async {
    await _securityService.createPin(pin);
    _pinSetupCompleted = true;
    _hasPin = true;
    _isUnlocked = true;
    _notifySafely();
  }

  Future<void> skipPinSetup() async {
    await _securityService.markPinSetupSkipped();
    _pinSetupCompleted = true;
    _hasPin = false;
    _isUnlocked = true;
    _notifySafely();
  }

  Future<bool> unlock(String pin) async {
    final isValid = await _securityService.verifyPin(pin);
    if (isValid) {
      _isUnlocked = true;
      _backgroundedAt = null;
      _notifySafely();
    }
    return isValid;
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
    _pinSetupCompleted = true;
    _hasPin = false;
    _isUnlocked = true;
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
            DateTime.now().difference(backgroundedAt) >= lockAfter) {
          lock();
        }
        break;
      case AppLifecycleState.detached:
        lock();
        break;
    }
  }

  void _notifySafely() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
