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

  int _selectedTab = 0;
  bool _hideLoginPassword = true;
  bool _hideRegisterPassword = true;

  @override
  void dispose() {
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    if (_selectedTab == index) return;
    AuthScope.read(context).clearMessages();
    setState(() => _selectedTab = index);
  }

  Future<void> _signIn() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_loginFormKey.currentState!.validate()) return;

    await AuthScope.read(context).signInWithEmailAndPassword(
      email: _loginEmailController.text,
      password: _loginPasswordController.text,
    );
  }

  Future<void> _register() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_registerFormKey.currentState!.validate()) return;

    await AuthScope.read(context).registerWithEmailAndPassword(
      email: _registerEmailController.text,
      password: _registerPasswordController.text,
    );
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
                      SizedBox(
                        height: 220,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.35),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.home_repair_service_outlined,
                                  color: Colors.white,
                                  size: 36,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Welcome to HomeVault',
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Manage appliances, warranties, documents, and service history.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight > 220
                              ? constraints.maxHeight - 220
                              : 0,
                        ),
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          26,
                          horizontalPadding,
                          32,
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _AuthTabs(
                                  selectedIndex: _selectedTab,
                                  onSelected: _selectTab,
                                ),
                                const SizedBox(height: 28),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 220),
                                  child: _selectedTab == 0
                                      ? _buildLoginForm(auth)
                                      : _buildRegistrationForm(auth),
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
                              ],
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
          TextFormField(
            key: const Key('loginEmailField'),
            controller: _loginEmailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Email',
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
              child: const Text('Forgot Password?'),
            ),
          ),
          const SizedBox(height: 6),
          FilledButton(
            key: const Key('loginButton'),
            onPressed: auth.isBusy ? null : _signIn,
            child: auth.isBusy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Log In'),
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
          TextFormField(
            key: const Key('registerEmailField'),
            controller: _registerEmailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Email',
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
              labelText: 'Confirm Password',
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
            'A verification link will be sent to your email before HomeVault setup continues.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 18),
          FilledButton(
            key: const Key('registerButton'),
            onPressed: auth.isBusy ? null : _register,
            child: auth.isBusy
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

class _AuthTabs extends StatelessWidget {
  const _AuthTabs({required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _AuthTab(
            label: 'Log In',
            isSelected: selectedIndex == 0,
            onTap: () => onSelected(0),
          ),
        ),
        Expanded(
          child: _AuthTab(
            label: 'Register',
            isSelected: selectedIndex == 1,
            onTap: () => onSelected(1),
          ),
        ),
      ],
    );
  }
}

class _AuthTab extends StatelessWidget {
  const _AuthTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Column(
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: isSelected ? primary : AppColors.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 3,
              width: isSelected ? 58 : 0,
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ),
      ),
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
