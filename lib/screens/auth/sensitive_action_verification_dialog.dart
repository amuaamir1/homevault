import 'package:flutter/material.dart';

import '../../auth/auth_scope.dart';

Future<bool> verifySensitiveAction(
  BuildContext context, {
  required String title,
  required String message,
  bool requireFreshVerification = false,
}) async {
  final auth = AuthScope.read(context);
  if (!requireFreshVerification && auth.hasRecentSensitiveAuthentication) {
    return true;
  }

  auth.clearMessages();
  final verified = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        _SensitiveActionVerificationDialog(title: title, message: message),
  );
  return verified == true;
}

class _SensitiveActionVerificationDialog extends StatefulWidget {
  const _SensitiveActionVerificationDialog({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  State<_SensitiveActionVerificationDialog> createState() =>
      _SensitiveActionVerificationDialogState();
}

class _SensitiveActionVerificationDialogState
    extends State<_SensitiveActionVerificationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _hidePassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _verifyPassword() async {
    if (!_formKey.currentState!.validate()) return;
    await _verify(
      () => AuthScope.read(
        context,
      ).reauthenticateWithPassword(_passwordController.text),
    );
  }

  Future<void> _verifyGoogle() {
    return _verify(() => AuthScope.read(context).reauthenticateWithGoogle());
  }

  Future<void> _verifyApple() {
    return _verify(() => AuthScope.read(context).reauthenticateWithApple());
  }

  Future<void> _verify(Future<bool> Function() operation) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final verified = await operation();
    if (!mounted || !verified) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final supportsPassword = auth.hasPasswordProvider;
    final supportsGoogle = auth.hasGoogleProvider;
    final supportsApple = auth.hasAppleProvider;
    final hasSupportedProvider =
        supportsPassword || supportsGoogle || supportsApple;

    return AlertDialog(
      key: const ValueKey('sensitiveActionVerificationDialog'),
      icon: const Icon(Icons.verified_user_outlined),
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.message),
              const SizedBox(height: 8),
              const Text(
                'Verify one of your HomeVault sign-in methods before continuing.',
              ),
              if (supportsPassword) ...[
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('sensitiveActionPasswordField'),
                  controller: _passwordController,
                  autofocus: true,
                  enabled: !auth.isBusy,
                  obscureText: _hidePassword,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'Account password',
                    prefixIcon: const Icon(Icons.password_outlined),
                    suffixIcon: IconButton(
                      onPressed: auth.isBusy
                          ? null
                          : () =>
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
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const ValueKey('sensitiveActionPasswordButton'),
                  onPressed: auth.isBusy ? null : _verifyPassword,
                  icon: const Icon(Icons.verified_user_outlined),
                  label: const Text('Verify with password'),
                ),
              ],
              if (supportsGoogle) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  key: const ValueKey('sensitiveActionGoogleButton'),
                  onPressed: auth.isBusy ? null : _verifyGoogle,
                  icon: const Icon(Icons.account_circle_outlined),
                  label: const Text('Verify with Google'),
                ),
              ],
              if (supportsApple) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  key: const ValueKey('sensitiveActionAppleButton'),
                  onPressed: auth.isBusy ? null : _verifyApple,
                  icon: const Icon(Icons.apple),
                  label: const Text('Verify with Apple'),
                ),
              ],
              if (!hasSupportedProvider) ...[
                const SizedBox(height: 14),
                const Text(
                  'HomeVault could not identify a supported verification method. '
                  'Sign out, sign in again, and retry this action.',
                ),
              ],
              if (auth.errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  auth.errorMessage!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (auth.isBusy) ...[
                const SizedBox(height: 14),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: auth.isBusy
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
