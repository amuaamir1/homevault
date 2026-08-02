import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../security/app_lock_scope.dart';
import '../../security/pin_security_service.dart';

class SecuritySettingsScreen extends StatelessWidget {
  const SecuritySettingsScreen({super.key});

  Future<void> _showCreatePin(BuildContext context) async {
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

  Future<void> _removePin(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove app PIN?'),
        content: const Text(
          'HomeVault will continue to require mobile OTP when you sign in, but the local PIN lock will be disabled on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove PIN'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await AppLockScope.read(context).removePin();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The local app PIN was removed.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lockController = AppLockScope.of(context);

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
                      'Add a 4 to 8 digit local PIN for quick protection.',
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
                    leading: const Icon(Icons.no_encryption_outlined),
                    title: const Text('Remove PIN'),
                    subtitle: const Text(
                      'Disable the local PIN lock on this device.',
                    ),
                    onTap: () => _removePin(context),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: const Text('Lock HomeVault now'),
                    subtitle: const Text('Return to the PIN unlock screen.'),
                    onTap: () {
                      final navigator = Navigator.of(context);
                      final controller = AppLockScope.read(context);
                      navigator.popUntil((route) => route.isFirst);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        controller.lock();
                      });
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Two layers of access'),
              subtitle: Text(
                'Mobile OTP verifies your account. The optional PIN protects HomeVault locally on this device and can be reset by verifying the mobile number again.',
              ),
            ),
          ),
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

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    await AppLockScope.read(context).createPin(_pinController.text);
    if (mounted) Navigator.of(context).pop(true);
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

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _currentPinError = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
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
