import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../security/app_lock_scope.dart';
import '../../security/pin_security_service.dart';

class SecuritySettingsScreen extends StatelessWidget {
  const SecuritySettingsScreen({super.key});

  Future<void> _changePin(BuildContext context) async {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Security')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.password_outlined),
                  title: const Text('Change PIN'),
                  subtitle: const Text('Replace your current 6-digit PIN.'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _changePin(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Lock HomeVault now'),
                  subtitle: const Text('Return to the PIN login screen.'),
                  onTap: () {
                    final navigator = Navigator.of(context);
                    final lockController = AppLockScope.read(context);
                    navigator.popUntil((route) => route.isFirst);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      lockController.lock();
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Local device security'),
              subtitle: Text(
                'This PIN protects HomeVault on this device. It is not an online account and cannot be recovered by email.',
              ),
            ),
          ),
        ],
      ),
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

  String? _validatePin(String? value) {
    if (!PinSecurityService.isValidPin(value ?? '')) {
      return 'Enter exactly 6 digits.';
    }
    return null;
  }

  Future<void> _submit() async {
    setState(() => _currentPinError = null);
    if (!_formKey.currentState!.validate()) {
      return;
    }

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
      maxLength: 6,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label, errorText: errorText),
      validator: validator,
    );
  }
}
