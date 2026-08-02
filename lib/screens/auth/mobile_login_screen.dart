import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth/auth_controller.dart';
import '../../auth/auth_scope.dart';

class MobileLoginScreen extends StatefulWidget {
  const MobileLoginScreen({super.key});

  @override
  State<MobileLoginScreen> createState() => _MobileLoginScreenState();
}

class _MobileLoginScreenState extends State<MobileLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();

  @override
  void dispose() {
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) return;
    await AuthScope.read(context).sendOtp(_mobileController.text);
  }

  String? _validateMobile(String? value) {
    final normalized = AuthController.normalizeIndianMobileNumber(value ?? '');
    if (normalized == null) {
      return 'Enter a valid 10-digit Indian mobile number.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);

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
                        Icons.home_repair_service_outlined,
                        size: 76,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Welcome to HomeVault',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Sign in with your Indian mobile number to manage your home appliances, warranties, documents, and service history.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 28),
                      TextFormField(
                        key: const Key('mobileNumberField'),
                        controller: _mobileController,
                        autofocus: true,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.done,
                        maxLength: 10,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        decoration: InputDecoration(
                          labelText: 'Mobile number',
                          hintText: '9876543210',
                          prefixIcon: const Icon(Icons.phone_android_outlined),
                          prefixText: '+91 ',
                          errorText: auth.errorMessage,
                        ),
                        validator: _validateMobile,
                        onChanged: (_) => auth.clearError(),
                        onFieldSubmitted: (_) => _sendOtp(),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        key: const Key('sendOtpButton'),
                        onPressed: auth.isSendingOtp ? null : _sendOtp,
                        icon: auth.isSendingOtp
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.sms_outlined),
                        label: Text(
                          auth.isSendingOtp ? 'Sending OTP...' : 'Send OTP',
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline, size: 20),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'By continuing, you agree to receive an SMS OTP. Your phone number is processed by Firebase and Google for authentication and abuse prevention.',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
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
