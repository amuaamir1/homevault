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
      _hasPin = true,
      _isUnlocked = true,
      _isTestBypass = true;

  final PinSecurityService _securityService;
  final Duration lockAfter;

  bool _isInitializing = true;
  bool _hasPin = false;
  bool _isUnlocked = false;
  bool _isDisposed = false;
  bool _isTestBypass = false;
  DateTime? _backgroundedAt;

  bool get isInitializing => _isInitializing;
  bool get hasPin => _hasPin;
  bool get isUnlocked => _isUnlocked;

  Future<void> initialize() async {
    if (_isTestBypass) {
      return;
    }

    WidgetsBinding.instance.addObserver(this);

    try {
      _hasPin = await _securityService.hasPin();
    } finally {
      _isInitializing = false;
      _notifySafely();
    }
  }

  Future<void> createPin(String pin) async {
    await _securityService.createPin(pin);
    _hasPin = true;
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
      _isUnlocked = true;
      _notifySafely();
    }
    return changed;
  }

  void lock() {
    if (!_hasPin || !_isUnlocked) {
      return;
    }

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
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
