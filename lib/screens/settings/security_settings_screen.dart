import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../security/app_lock_scope.dart';
import '../../security/auto_lock_preference_service.dart';
import '../../security/pin_security_service.dart';
import '../../services/homevault_error_presenter.dart';
import '../auth/reset_pin_with_password_screen.dart';
import '../auth/sensitive_action_verification_dialog.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppLockScope.read(context).refreshBiometricState();
    });
  }

  Future<void> _showCreatePin(BuildContext context) async {
    final verified = await verifySensitiveAction(
      context,
      title: 'Verify before creating a PIN',
      message:
          'Creating a HomeVault PIN changes how this account is protected on '
          'this device.',
    );
    if (!context.mounted || !verified) return;

    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _CreatePinDialog(),
    );
    if (created == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your HomeVault PIN was created.')),
      );
    }
  }

  Future<void> _showChangePin(BuildContext context) async {
    final verified = await verifySensitiveAction(
      context,
      title: 'Verify before changing your PIN',
      message:
          'Changing your HomeVault PIN changes the credential used to unlock '
          'this account on this device.',
    );
    if (!context.mounted || !verified) return;

    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _ChangePinDialog(),
    );
    if (changed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your HomeVault PIN was changed.')),
      );
    }
  }

  Future<void> _changeAutoLockOption(
    BuildContext context,
    AutoLockOption option,
  ) async {
    final controller = AppLockScope.read(context);
    if (option.duration > controller.autoLockOption.duration) {
      final verified = await verifySensitiveAction(
        context,
        title: 'Verify before extending auto-lock',
        message:
            'A longer automatic-lock delay keeps HomeVault unlocked for more '
            'time after you leave the app.',
      );
      if (!context.mounted || !verified) return;
    }

    await controller.setAutoLockOption(option);
  }

  Future<void> _toggleBiometrics(BuildContext context, bool enabled) async {
    if (enabled) {
      final verified = await verifySensitiveAction(
        context,
        title: 'Verify before enabling biometrics',
        message:
            'Biometric unlock adds another way to open HomeVault on this '
            'device.',
      );
      if (!context.mounted || !verified) return;
    }

    final controller = AppLockScope.read(context);
    final changed = await controller.setBiometricEnabled(enabled);
    if (!context.mounted) return;

    if (changed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? '${controller.biometricLabel} enabled for HomeVault.'
                : 'Biometric unlock disabled.',
          ),
        ),
      );
      return;
    }

    final message = controller.biometricErrorMessage;
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lockController = AppLockScope.of(context);

    final biometricSubtitle = !lockController.hasPin
        ? 'Create a HomeVault PIN before enabling biometric unlock.'
        : !lockController.isBiometricAvailable
        ? lockController.biometricErrorMessage ??
              'Set up fingerprint or face unlock in Android settings.'
        : lockController.isBiometricEnabled
        ? 'Use ${lockController.biometricLabel} instead of typing your PIN.'
        : 'Enable ${lockController.biometricLabel} for faster unlocking.';

    return Scaffold(
      appBar: AppBar(title: const Text('Security')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                if (!lockController.hasPin)
                  ListTile(
                    leading: const Icon(Icons.add_moderator_outlined),
                    title: const Text('Create app PIN'),
                    subtitle: const Text(
                      'Create a required 4 to 8 digit HomeVault PIN.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showCreatePin(context),
                  )
                else ...[
                  ListTile(
                    leading: const Icon(Icons.password_outlined),
                    title: const Text('Change PIN'),
                    subtitle: const Text(
                      'Replace your current 4 to 8 digit PIN.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showChangePin(context),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.lock_reset_outlined),
                    title: const Text('Reset forgotten PIN'),
                    subtitle: const Text(
                      'Verify your HomeVault account, then create a new PIN.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ResetPinWithPasswordScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.fingerprint),
              title: const Text('Biometric unlock'),
              subtitle: Text(biometricSubtitle),
              value: lockController.isBiometricEnabled,
              onChanged:
                  lockController.hasPin &&
                      lockController.isBiometricAvailable &&
                      !lockController.isAuthenticatingBiometric
                  ? (value) => _toggleBiometrics(context, value)
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text('Automatic lock'),
              subtitle: Text(lockController.autoLockOption.label),
              trailing: DropdownButton<AutoLockOption>(
                value: lockController.autoLockOption,
                underline: const SizedBox.shrink(),
                items: AutoLockOption.values
                    .map(
                      (option) => DropdownMenuItem(
                        value: option,
                        child: Text(option.label),
                      ),
                    )
                    .toList(),
                onChanged: (option) {
                  if (option != null) {
                    _changeAutoLockOption(context, option);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _CreatePinDialog extends StatefulWidget {
  const _CreatePinDialog();

  @override
  State<_CreatePinDialog> createState() => _CreatePinDialogState();
}

class _CreatePinDialogState extends State<_CreatePinDialog> {
  final _formKey = GlobalKey<FormState>();
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isSaving = false;
  String? _pinError;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _pinError = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await AppLockScope.read(context).createPin(_pinController.text);
      if (mounted) Navigator.of(context).pop(true);
    } on PinReuseException catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _pinError = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      showHomeVaultError(
        context,
        error,
        fallback: 'The PIN could not be saved. Please try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create app PIN'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PinField(
                controller: _pinController,
                label: 'New PIN',
                errorText: _pinError,
                validator: _validatePin,
              ),
              const SizedBox(height: 10),
              _PinField(
                controller: _confirmController,
                label: 'Confirm PIN',
                validator: (value) {
                  final validation = _validatePin(value);
                  if (validation != null) return validation;
                  if (value != _pinController.text) {
                    return 'The PINs do not match.';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _submit,
          child: Text(_isSaving ? 'Saving...' : 'Create PIN'),
        ),
      ],
    );
  }
}

class _ChangePinDialog extends StatefulWidget {
  const _ChangePinDialog();

  @override
  State<_ChangePinDialog> createState() => _ChangePinDialogState();
}

class _ChangePinDialogState extends State<_ChangePinDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isSaving = false;
  String? _currentPinError;
  String? _newPinError;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _currentPinError = null;
      _newPinError = null;
    });
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final changed = await AppLockScope.read(context).changePin(
        currentPin: _currentController.text,
        newPin: _newController.text,
      );

      if (!mounted) return;
      if (changed) {
        Navigator.of(context).pop(true);
        return;
      }

      setState(() {
        _isSaving = false;
        _currentPinError = 'The current PIN is incorrect.';
      });
    } on PinReuseException catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _newPinError = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      showHomeVaultError(
        context,
        error,
        fallback: 'The PIN could not be changed. Please try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change PIN'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PinField(
                controller: _currentController,
                label: 'Current PIN',
                errorText: _currentPinError,
                validator: _validatePin,
              ),
              const SizedBox(height: 10),
              _PinField(
                controller: _newController,
                label: 'New PIN',
                errorText: _newPinError,
                validator: _validatePin,
              ),
              const SizedBox(height: 10),
              _PinField(
                controller: _confirmController,
                label: 'Confirm new PIN',
                validator: (value) {
                  final validation = _validatePin(value);
                  if (validation != null) return validation;
                  if (value != _newController.text) {
                    return 'The new PINs do not match.';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _submit,
          child: Text(_isSaving ? 'Saving...' : 'Change PIN'),
        ),
      ],
    );
  }
}

String? _validatePin(String? value) {
  if (!PinSecurityService.isValidPin(value ?? '')) {
    return 'Enter a PIN containing 4 to 8 digits.';
  }
  return null;
}

class _PinField extends StatelessWidget {
  const _PinField({
    required this.controller,
    required this.label,
    required this.validator,
    this.errorText,
  });

  final TextEditingController controller;
  final String label;
  final String? errorText;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: true,
      keyboardType: TextInputType.number,
      maxLength: 8,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(8),
      ],
      decoration: InputDecoration(labelText: label, errorText: errorText),
      validator: validator,
    );
  }
}
