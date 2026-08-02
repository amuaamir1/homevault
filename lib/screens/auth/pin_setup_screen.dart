import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../security/app_lock_scope.dart';
import '../../security/pin_security_service.dart';

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key, this.allowSkip = true});

  final bool allowSkip;

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _hidePin = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _savePin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await AppLockScope.read(context).createPin(_pinController.text);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The PIN could not be saved. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _skip() async {
    setState(() => _isSaving = true);
    try {
      await AppLockScope.read(context).skipPinSetup();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String? _validatePin(String? value) {
    if (!PinSecurityService.isValidPin(value ?? '')) {
      return 'Enter a PIN containing 4 to 8 digits.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 72,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Protect HomeVault',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create an optional 4 to 8 digit PIN for quick local protection on this device.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 28),
                      _PinField(
                        key: const Key('createPinField'),
                        controller: _pinController,
                        label: 'Create PIN',
                        obscureText: _hidePin,
                        validator: _validatePin,
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
                      const SizedBox(height: 10),
                      _PinField(
                        key: const Key('confirmPinField'),
                        controller: _confirmController,
                        label: 'Confirm PIN',
                        obscureText: _hidePin,
                        validator: (value) {
                          final validation = _validatePin(value);
                          if (validation != null) return validation;
                          if (value != _pinController.text) {
                            return 'The PINs do not match.';
                          }
                          return null;
                        },
                        onSubmitted: (_) => _savePin(),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        key: const Key('createPinButton'),
                        onPressed: _isSaving ? null : _savePin,
                        icon: _isSaving
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.lock_outline),
                        label: Text(_isSaving ? 'Saving...' : 'Create PIN'),
                      ),
                      if (widget.allowSkip)
                        TextButton(
                          key: const Key('skipPinButton'),
                          onPressed: _isSaving ? null : _skip,
                          child: const Text('Skip for now'),
                        ),
                      const SizedBox(height: 12),
                      const Text(
                        'You can create, change, or remove the PIN later from Settings → Security.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinField extends StatelessWidget {
  const _PinField({
    super.key,
    required this.controller,
    required this.label,
    required this.obscureText,
    required this.validator,
    this.suffixIcon,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final String? Function(String?) validator;
  final Widget? suffixIcon;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: TextInputType.number,
      textInputAction: onSubmitted == null
          ? TextInputAction.next
          : TextInputAction.done,
      maxLength: 8,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(8),
      ],
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.pin_outlined),
        suffixIcon: suffixIcon,
      ),
      validator: validator,
      onFieldSubmitted: onSubmitted,
    );
  }
}
