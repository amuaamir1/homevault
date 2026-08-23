import 'package:flutter/material.dart';

import '../../auth/auth_scope.dart';
import '../../security/app_lock_scope.dart';
import '../../services/account_deletion_service.dart';
import '../../services/homevault_error_message.dart';

class AccountDeletionScreen extends StatefulWidget {
  const AccountDeletionScreen({super.key});

  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  final _confirmationController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _hidePassword = true;
  bool _isDeleting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _confirmationController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _confirmed => _confirmationController.text.trim() == 'DELETE';

  Future<void> _deleteWithPassword() async {
    if (_passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Enter your account password.');
      return;
    }
    await _deleteAccount(
      () => AuthScope.read(
        context,
      ).reauthenticateWithPassword(_passwordController.text),
    );
  }

  Future<void> _deleteWithGoogle() {
    return _deleteAccount(
      () => AuthScope.read(context).reauthenticateWithGoogle(),
    );
  }

  Future<void> _deleteWithApple() {
    return _deleteAccount(
      () => AuthScope.read(context).reauthenticateWithApple(),
    );
  }

  Future<void> _deleteAccount(Future<bool> Function() verifyAccount) async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_confirmed || _isDeleting) {
      setState(() {
        _errorMessage = 'Type DELETE exactly to confirm account deletion.';
      });
      return;
    }

    setState(() {
      _isDeleting = true;
      _errorMessage = null;
    });

    final auth = AuthScope.read(context);
    final user = auth.user;
    if (user == null) {
      if (mounted) {
        setState(() {
          _isDeleting = false;
          _errorMessage = 'Your HomeVault session has expired.';
        });
      }
      return;
    }

    final verified = await verifyAccount();
    if (!mounted || !verified) {
      if (mounted) {
        setState(() {
          _isDeleting = false;
          _errorMessage = auth.errorMessage ?? 'Account verification failed.';
        });
      }
      return;
    }

    final deletionService = AccountDeletionService();
    final lockController = AppLockScope.read(context);

    try {
      await deletionService.deleteRemoteAccountData(user.uid);

      // Large accounts can take long enough to exhaust HomeVault's short
      // recent-authentication window. Re-verify before the irreversible
      // Firebase Authentication deletion rather than trusting stale proof.
      if (!auth.hasRecentSensitiveAuthentication) {
        final reverified = await verifyAccount();
        if (!mounted || !reverified) {
          if (mounted) {
            setState(() {
              _isDeleting = false;
              _errorMessage =
                  auth.errorMessage ??
                  'Verify your account again to finish deleting it.';
            });
          }
          return;
        }
      }

      final authDeleted = await auth.deleteCurrentAccount();
      if (authDeleted) {
        // Local cleanup does not need Firebase authorization, so keep local
        // data available until the sign-in account deletion has succeeded.
        // Always clear local security state even if filesystem cleanup hits
        // an unexpected error after Firebase Authentication is already gone.
        try {
          await deletionService.deleteLocalAccountData(user.uid);
        } finally {
          await lockController.clearSecurityForDeletedAccount();
        }
        return;
      }
      if (!mounted) return;

      setState(() {
        _isDeleting = false;
        _errorMessage =
            auth.errorMessage ??
            'The HomeVault cloud data was removed, but the sign-in account '
                'could not be deleted. Verify your account again and retry.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isDeleting = false;
        _errorMessage = friendlyHomeVaultError(
          error,
          fallback:
              'HomeVault could not finish deleting the account. Please retry.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final supportsPassword = auth.hasPasswordProvider;
    final supportsGoogle = auth.hasGoogleProvider;
    final supportsApple = auth.hasAppleProvider;
    final hasSupportedProvider =
        supportsPassword || supportsGoogle || supportsApple;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Delete account')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'This permanently deletes your HomeVault account',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: colorScheme.onErrorContainer,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Appliances, warranties, AMC details, service history, '
                      'documents, appliance photos, cloud backups, profile '
                      'data, feedback, and local security data for this '
                      'account will be removed.',
                      style: TextStyle(color: colorScheme.onErrorContainer),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Before deleting',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a backup first if you may need your HomeVault records '
              'later. Account deletion cannot be undone.',
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _confirmationController,
              enabled: !_isDeleting,
              decoration: InputDecoration(
                labelText: 'Type DELETE to confirm',
                prefixIcon: const Icon(Icons.delete_forever_outlined),
                errorText: _errorMessage,
              ),
              onChanged: (_) {
                if (_errorMessage != null) {
                  setState(() => _errorMessage = null);
                } else {
                  setState(() {});
                }
              },
            ),
            const SizedBox(height: 16),
            if (supportsPassword) ...[
              TextField(
                controller: _passwordController,
                enabled: !_isDeleting,
                obscureText: _hidePassword,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: 'Account password',
                  prefixIcon: const Icon(Icons.password_outlined),
                  suffixIcon: IconButton(
                    onPressed: _isDeleting
                        ? null
                        : () => setState(() => _hidePassword = !_hidePassword),
                    icon: Icon(
                      _hidePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.error,
                  foregroundColor: colorScheme.onError,
                ),
                onPressed: !_confirmed || _isDeleting
                    ? null
                    : _deleteWithPassword,
                icon: const Icon(Icons.delete_forever_outlined),
                label: const Text('Verify password and delete account'),
              ),
            ],
            if (supportsGoogle) ...[
              if (supportsPassword) const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: !_confirmed || _isDeleting
                    ? null
                    : _deleteWithGoogle,
                icon: const Icon(Icons.account_circle_outlined),
                label: const Text('Verify with Google and delete account'),
              ),
            ],
            if (supportsApple) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: !_confirmed || _isDeleting ? null : _deleteWithApple,
                icon: const Icon(Icons.apple),
                label: const Text('Verify with Apple and delete account'),
              ),
            ],
            if (!hasSupportedProvider)
              const Text(
                'No supported verification method was detected. Sign out, '
                'sign in again, and retry account deletion.',
              ),
            if (_isDeleting) ...[
              const SizedBox(height: 20),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 8),
              const Text(
                'Deleting HomeVault account data...',
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
