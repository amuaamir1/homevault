import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../profile/profile_scope.dart';
import '../../security/app_lock_scope.dart';
import '../../security/pin_security_service.dart';
import 'reset_pin_with_password_screen.dart';

class PinLoginScreen extends StatefulWidget {
  const PinLoginScreen({super.key});

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen> {
  final _pinController = TextEditingController();
  bool _hidePin = true;
  bool _isChecking = false;
  bool _autoBiometricRequested = false;
  String? _errorText;
  int _failedAttempts = 0;
  DateTime? _lockedUntil;
  Timer? _countdownTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final controller = AppLockScope.of(context);
    if (!_autoBiometricRequested &&
        controller.isBiometricEnabled &&
        controller.isBiometricAvailable) {
      _autoBiometricRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _unlockWithBiometrics(automatic: true);
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pinController.dispose();
    super.dispose();
  }

  bool get _isTemporarilyLocked {
    final lockedUntil = _lockedUntil;
    return lockedUntil != null && DateTime.now().isBefore(lockedUntil);
  }

  int get _lockSecondsRemaining {
    final lockedUntil = _lockedUntil;
    if (lockedUntil == null) return 0;
    final seconds = lockedUntil.difference(DateTime.now()).inSeconds + 1;
    return seconds < 0 ? 0 : seconds;
  }

  Future<void> _unlock() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_isTemporarilyLocked || _isChecking) return;

    final pin = _pinController.text;
    if (!PinSecurityService.isValidPin(pin)) {
      setState(() => _errorText = 'Enter your 4 to 8 digit PIN.');
      return;
    }

    setState(() {
      _isChecking = true;
      _errorText = null;
    });

    final isValid = await AppLockScope.read(context).unlock(pin);
    if (!mounted || isValid) return;

    _failedAttempts += 1;
    _pinController.clear();

    if (_failedAttempts >= 5) {
      _failedAttempts = 0;
      _lockedUntil = DateTime.now().add(const Duration(seconds: 30));
      _startCountdown();
      setState(() {
        _isChecking = false;
        _errorText = 'Too many attempts. Try again in 30 seconds.';
      });
      return;
    }

    setState(() {
      _isChecking = false;
      _errorText = 'Incorrect PIN. Please try again.';
    });
  }

  Future<void> _unlockWithBiometrics({bool automatic = false}) async {
    if (_isTemporarilyLocked || _isChecking) return;

    setState(() {
      _isChecking = true;
      if (!automatic) _errorText = null;
    });

    final controller = AppLockScope.read(context);
    final authenticated = await controller.authenticateWithBiometrics();
    if (!mounted || authenticated) return;

    setState(() {
      _isChecking = false;
      if (controller.biometricErrorMessage != null) {
        _errorText = controller.biometricErrorMessage;
      }
    });
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (!_isTemporarilyLocked) {
        timer.cancel();
        setState(() {
          _lockedUntil = null;
          _errorText = null;
        });
      } else {
        setState(() {});
      }
    });
  }

  void _resetWithPassword() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ResetPinWithPasswordScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locked = _isTemporarilyLocked;
    final lockController = AppLockScope.of(context);
    final firstName = ProfileScope.of(context).profile?.firstName ?? '';
    final welcomeText = firstName.isEmpty
        ? 'Unlock HomeVault'
        : 'Welcome $firstName';

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.lock_person_outlined,
                      size: 72,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      welcomeText,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter your HomeVault PIN or use ${lockController.biometricLabel}.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 28),
                    TextField(
                      key: const Key('homeVaultPinField'),
                      controller: _pinController,
                      autofocus: !lockController.isBiometricEnabled,
                      enabled: !locked && !_isChecking,
                      obscureText: _hidePin,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      maxLength: 8,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(8),
                      ],
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'PIN',
                        errorText: _errorText,
                        prefixIcon: const Icon(Icons.pin_outlined),
                        suffixIcon: IconButton(
                          tooltip: _hidePin ? 'Show PIN' : 'Hide PIN',
                          onPressed: () => setState(() => _hidePin = !_hidePin),
                          icon: Icon(
                            _hidePin
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      onSubmitted: (_) => _unlock(),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: locked || _isChecking ? null : _unlock,
                      icon: _isChecking
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: Text(
                        locked
                            ? 'Try again in $_lockSecondsRemaining seconds'
                            : _isChecking
                            ? 'Checking...'
                            : 'Unlock with PIN',
                      ),
                    ),
                    if (lockController.isBiometricEnabled &&
                        lockController.isBiometricAvailable) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: locked || _isChecking
                            ? null
                            : _unlockWithBiometrics,
                        icon: const Icon(Icons.fingerprint),
                        label: Text('Use ${lockController.biometricLabel}'),
                      ),
                    ],
                    TextButton(
                      onPressed: locked || _isChecking
                          ? null
                          : _resetWithPassword,
                      child: const Text('Forgot PIN? Verify account password'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
