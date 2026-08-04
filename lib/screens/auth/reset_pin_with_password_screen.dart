import 'package:flutter/material.dart';

import '../../auth/auth_scope.dart';
import '../../security/app_lock_scope.dart';

class ResetPinWithPasswordScreen extends StatefulWidget {
  const ResetPinWithPasswordScreen({super.key});

  @override
  State<ResetPinWithPasswordScreen> createState() =>
      _ResetPinWithPasswordScreenState();
}

class _ResetPinWithPasswordScreenState
    extends State<ResetPinWithPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _hidePassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) return;

    final verified = await AuthScope.read(
      context,
    ).reauthenticateWithPassword(_passwordController.text);
    if (!mounted || !verified) return;

    await AppLockScope.read(context).resetPinForAccountRecovery();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Reset HomeVault PIN')),
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
                      Icons.lock_reset_outlined,
                      size: 70,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Verify your account',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(auth.user?.email ?? '', textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter your HomeVault account password to create a new local PIN.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _passwordController,
                      autofocus: true,
                      obscureText: _hidePassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Account password',
                        prefixIcon: const Icon(Icons.password_outlined),
                        errorText: auth.errorMessage,
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setState(() => _hidePassword = !_hidePassword),
                          icon: Icon(
                            _hidePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) => (value ?? '').isEmpty
                          ? 'Enter your account password.'
                          : null,
                      onChanged: (_) => auth.clearMessages(),
                      onFieldSubmitted: (_) => _continue(),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: auth.isBusy ? null : _continue,
                      icon: auth.isBusy
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.verified_user_outlined),
                      label: Text(
                        auth.isBusy ? 'Verifying...' : 'Verify and reset PIN',
                      ),
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
