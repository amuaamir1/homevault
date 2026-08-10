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

  Future<void> _resetAfterVerification(bool verified) async {
    if (!mounted || !verified) return;

    await AppLockScope.read(context).resetPinForAccountRecovery();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _verifyPassword() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) return;

    final verified = await AuthScope.read(
      context,
    ).reauthenticateWithPassword(_passwordController.text);
    await _resetAfterVerification(verified);
  }

  Future<void> _verifyGoogle() async {
    final verified = await AuthScope.read(context).reauthenticateWithGoogle();
    await _resetAfterVerification(verified);
  }

  Future<void> _verifyApple() async {
    final verified = await AuthScope.read(context).reauthenticateWithApple();
    await _resetAfterVerification(verified);
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final supportsPassword = auth.hasPasswordProvider;
    final supportsGoogle = auth.hasGoogleProvider;
    final supportsApple = auth.hasAppleProvider;
    final hasSupportedProvider =
        supportsPassword || supportsGoogle || supportsApple;

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
                      'Verify using one of your sign-in methods. HomeVault will '
                      'then ask you to create a new local PIN.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    if (supportsPassword) ...[
                      TextFormField(
                        controller: _passwordController,
                        autofocus: true,
                        obscureText: _hidePassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: 'Account password',
                          prefixIcon: const Icon(Icons.password_outlined),
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
                        onFieldSubmitted: (_) => _verifyPassword(),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: auth.isBusy ? null : _verifyPassword,
                        icon: const Icon(Icons.verified_user_outlined),
                        label: const Text('Verify with password'),
                      ),
                    ],
                    if (supportsGoogle) ...[
                      if (supportsPassword) const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: auth.isBusy ? null : _verifyGoogle,
                        icon: const Icon(Icons.account_circle_outlined),
                        label: const Text('Verify with Google'),
                      ),
                    ],
                    if (supportsApple) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: auth.isBusy ? null : _verifyApple,
                        icon: const Icon(Icons.apple),
                        label: const Text('Verify with Apple'),
                      ),
                    ],
                    if (!hasSupportedProvider) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'HomeVault could not identify a supported sign-in '
                            'method for this account. Sign out, sign in again, '
                            'and retry PIN recovery.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                    if (auth.errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        auth.errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    if (auth.isBusy) ...[
                      const SizedBox(height: 16),
                      const Center(child: CircularProgressIndicator()),
                    ],
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
