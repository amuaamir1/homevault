import 'package:flutter/material.dart';

import '../../auth/auth_controller.dart';
import '../../auth/auth_scope.dart';
import '../../theme/app_colors.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isRegistering = false;
  bool _hideLoginPassword = true;
  bool _hideRegisterPassword = true;
  _AuthAction? _activeAction;

  @override
  void dispose() {
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _switchMode({required bool register}) {
    if (_isRegistering == register) return;

    FocusManager.instance.primaryFocus?.unfocus();
    AuthScope.read(context).clearMessages();
    setState(() {
      _isRegistering = register;
      _activeAction = null;
    });
  }

  Future<void> _signIn() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_loginFormKey.currentState!.validate()) return;

    await _runAction(
      _AuthAction.emailSignIn,
      () => AuthScope.read(context).signInWithEmailAndPassword(
        email: _loginEmailController.text,
        password: _loginPasswordController.text,
      ),
    );
  }

  Future<void> _register() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_registerFormKey.currentState!.validate()) return;

    await _runAction(
      _AuthAction.emailRegister,
      () => AuthScope.read(context).registerWithEmailAndPassword(
        email: _registerEmailController.text,
        password: _registerPasswordController.text,
      ),
    );
  }

  Future<void> _signInWithGoogle() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await _runAction(
      _AuthAction.google,
      () => AuthScope.read(context).signInWithGoogle(),
    );
  }

  Future<void> _signInWithApple() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await _runAction(
      _AuthAction.apple,
      () => AuthScope.read(context).signInWithApple(),
    );
  }

  Future<void> _runAction(
    _AuthAction action,
    Future<bool> Function() operation,
  ) async {
    setState(() => _activeAction = action);
    await operation();

    if (mounted) {
      setState(() => _activeAction = null);
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final emailController = TextEditingController(
      text: _loginEmailController.text.trim(),
    );
    final formKey = GlobalKey<FormState>();

    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset password'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: emailController,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Email address',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (value) =>
                AuthController.normalizeEmail(value ?? '') == null
                ? 'Enter a valid email address.'
                : null,
            onFieldSubmitted: (_) {
              if (formKey.currentState!.validate()) {
                Navigator.of(dialogContext).pop(emailController.text);
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(dialogContext).pop(emailController.text);
              }
            },
            child: const Text('Send reset link'),
          ),
        ],
      ),
    );

    emailController.dispose();
    if (email == null || !mounted) return;

    final sent = await AuthScope.read(context).sendPasswordResetEmail(email);
    if (!mounted || !sent) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Password reset instructions were sent by email.'),
      ),
    );
  }

  String? _validateEmail(String? value) {
    return AuthController.normalizeEmail(value ?? '') == null
        ? 'Enter a valid email address.'
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final media = MediaQuery.of(context);
    final horizontalPadding = media.size.width < 380 ? 20.0 : 28.0;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    children: [
                      _HomeVaultHeader(compact: constraints.maxHeight < 720),
                      Container(
                        width: double.infinity,
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight > 180
                              ? constraints.maxHeight - 180
                              : 0,
                        ),
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          28,
                          horizontalPadding,
                          30,
                        ),
                        decoration: const BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(30),
                          ),
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: AutofillGroup(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 220),
                                    child: _isRegistering
                                        ? _buildRegistrationForm(auth)
                                        : _buildLoginForm(auth),
                                  ),
                                  if (auth.errorMessage != null) ...[
                                    const SizedBox(height: 16),
                                    _MessagePanel(
                                      icon: Icons.error_outline,
                                      message: auth.errorMessage!,
                                      isError: true,
                                    ),
                                  ],
                                  if (auth.statusMessage != null) ...[
                                    const SizedBox(height: 16),
                                    _MessagePanel(
                                      icon: Icons.check_circle_outline,
                                      message: auth.statusMessage!,
                                    ),
                                  ],
                                  const SizedBox(height: 26),
                                  const _SocialDivider(),
                                  const SizedBox(height: 18),
                                  _SocialSignInButton(
                                    key: const Key('googleSignInButton'),
                                    label: 'Continue with Google',
                                    icon: const _GoogleMark(),
                                    isLoading:
                                        _activeAction == _AuthAction.google,
                                    onPressed: auth.isBusy
                                        ? null
                                        : _signInWithGoogle,
                                  ),
                                  const SizedBox(height: 12),
                                  _SocialSignInButton(
                                    key: const Key('appleSignInButton'),
                                    label: 'Continue with Apple',
                                    icon: const Icon(Icons.apple, size: 24),
                                    isLoading:
                                        _activeAction == _AuthAction.apple,
                                    onPressed: auth.isBusy
                                        ? null
                                        : _signInWithApple,
                                  ),
                                  const SizedBox(height: 24),
                                  _AuthModePrompt(
                                    isRegistering: _isRegistering,
                                    isBusy: auth.isBusy,
                                    onSwitch: () =>
                                        _switchMode(register: !_isRegistering),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm(AuthController auth) {
    return Form(
      key: _loginFormKey,
      child: Column(
        key: const ValueKey('loginForm'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Sign in to HomeVault',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Use your verified email and password.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          TextFormField(
            key: const Key('loginEmailField'),
            controller: _loginEmailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Email address',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: _validateEmail,
            onChanged: (_) => auth.clearMessages(),
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('loginPasswordField'),
            controller: _loginPasswordController,
            obscureText: _hideLoginPassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: _hideLoginPassword ? 'Show password' : 'Hide password',
                onPressed: () =>
                    setState(() => _hideLoginPassword = !_hideLoginPassword),
                icon: Icon(
                  _hideLoginPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (value) =>
                (value ?? '').isEmpty ? 'Enter your password.' : null,
            onChanged: (_) => auth.clearMessages(),
            onFieldSubmitted: (_) => _signIn(),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: auth.isBusy ? null : _showForgotPasswordDialog,
              child: const Text('Forgot password?'),
            ),
          ),
          const SizedBox(height: 6),
          FilledButton(
            key: const Key('loginButton'),
            onPressed: auth.isBusy ? null : _signIn,
            child: _activeAction == _AuthAction.emailSignIn
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Sign in'),
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrationForm(AuthController auth) {
    return Form(
      key: _registerFormKey,
      child: Column(
        key: const ValueKey('registrationForm'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Create your HomeVault account',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Register with email, Google, or Apple.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          TextFormField(
            key: const Key('registerEmailField'),
            controller: _registerEmailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Email address',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: _validateEmail,
            onChanged: (_) => auth.clearMessages(),
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('registerPasswordField'),
            controller: _registerPasswordController,
            obscureText: _hideRegisterPassword,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: _hideRegisterPassword
                    ? 'Show password'
                    : 'Hide password',
                onPressed: () => setState(
                  () => _hideRegisterPassword = !_hideRegisterPassword,
                ),
                icon: Icon(
                  _hideRegisterPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (value) => AuthController.validatePassword(value ?? ''),
            onChanged: (_) => auth.clearMessages(),
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('confirmRegistrationPasswordField'),
            controller: _confirmPasswordController,
            obscureText: _hideRegisterPassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            decoration: const InputDecoration(
              labelText: 'Confirm password',
              prefixIcon: Icon(Icons.lock_reset_outlined),
            ),
            validator: (value) => value != _registerPasswordController.text
                ? 'Passwords do not match.'
                : null,
            onChanged: (_) => auth.clearMessages(),
            onFieldSubmitted: (_) => _register(),
          ),
          const SizedBox(height: 12),
          Text(
            'A verification link will be sent to your email before HomeVault setup continues. Check Spam if it does not appear in your inbox.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 18),
          FilledButton(
            key: const Key('registerButton'),
            onPressed: auth.isBusy ? null : _register,
            child: _activeAction == _AuthAction.emailRegister
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Register'),
          ),
        ],
      ),
    );
  }
}

enum _AuthAction { emailSignIn, emailRegister, google, apple }

class _HomeVaultHeader extends StatelessWidget {
  const _HomeVaultHeader({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 150 : 180,
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, compact ? 18 : 24, 24, 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: compact ? 58 : 66,
              height: compact ? 58 : 66,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
              ),
              child: Icon(
                Icons.home_repair_service_outlined,
                color: Colors.white,
                size: compact ? 31 : 35,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'HomeVault',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialDivider extends StatelessWidget {
  const _SocialDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR CONTINUE WITH',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _SocialSignInButton extends StatelessWidget {
  const _SocialSignInButton({
    super.key,
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final Widget icon;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: isLoading
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [icon, const SizedBox(width: 12), Text(label)],
            ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 24,
      child: Center(
        child: Text(
          'G',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _AuthModePrompt extends StatelessWidget {
  const _AuthModePrompt({
    required this.isRegistering,
    required this.isBusy,
    required this.onSwitch,
  });

  final bool isRegistering;
  final bool isBusy;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          isRegistering
              ? 'Already have an account?'
              : "Don't have an account yet?",
        ),
        TextButton(
          key: const Key('switchAuthModeButton'),
          onPressed: isBusy ? null : onSwitch,
          child: Text(isRegistering ? 'Sign in' : 'Register'),
        ),
      ],
    );
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({
    required this.icon,
    required this.message,
    this.isError = false,
  });

  final IconData icon;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError
        ? Theme.of(context).colorScheme.error
        : AppColors.success;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }
}
