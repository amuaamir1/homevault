import 'package:flutter/material.dart';

import '../../auth/auth_scope.dart';

class EmailVerificationScreen extends StatelessWidget {
  const EmailVerificationScreen({super.key});

  Future<void> _check(BuildContext context) async {
    final verified = await AuthScope.read(context).refreshEmailVerification();
    if (!context.mounted || !verified) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Email verified successfully.')),
    );
  }

  Future<void> _resend(BuildContext context) async {
    final sent = await AuthScope.read(context).resendVerificationEmail();
    if (!context.mounted || !sent) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('A new verification email was sent.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final email = auth.user?.email ?? '';

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
                      Icons.mark_email_unread_outlined,
                      size: 76,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Verify your email',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'We sent a verification link to\n$email',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Open the link from your inbox, then return to HomeVault and continue.',
                      textAlign: TextAlign.center,
                    ),
                    if (auth.errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        auth.errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      key: const Key('checkEmailVerificationButton'),
                      onPressed: auth.isBusy ? null : () => _check(context),
                      icon: auth.isBusy
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.verified_outlined),
                      label: Text(
                        auth.isBusy ? 'Checking...' : 'I verified my email',
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: auth.isBusy ? null : () => _resend(context),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Resend verification email'),
                    ),
                    TextButton(
                      onPressed: auth.isBusy ? null : auth.signOut,
                      child: const Text('Use a different email'),
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
