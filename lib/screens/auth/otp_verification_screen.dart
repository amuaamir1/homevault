import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth/auth_scope.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  Timer? _timer;
  int _resendSeconds = 30;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _resendSeconds = 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds -= 1);
      }
    });
  }

  Future<void> _verify() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await AuthScope.read(context).verifyOtp(_otpController.text);
  }

  Future<void> _resend() async {
    final auth = AuthScope.read(context);
    final phoneNumber = auth.pendingPhoneNumber;
    if (phoneNumber == null) return;
    final sent = await auth.sendOtp(phoneNumber, resend: true);
    if (sent && mounted) {
      _otpController.clear();
      _startTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final phoneNumber = auth.pendingPhoneNumber ?? '';

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Change mobile number',
            onPressed: auth.isVerifyingOtp ? null : auth.editPhoneNumber,
            icon: const Icon(Icons.arrow_back),
          ),
          title: const Text('Verify mobile number'),
        ),
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
                      Icons.sms_outlined,
                      size: 72,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Enter the OTP',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'We sent a 6-digit verification code to $phoneNumber.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    TextField(
                      key: const Key('otpField'),
                      controller: _otpController,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      maxLength: 6,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      autofillHints: const [AutofillHints.oneTimeCode],
                      decoration: InputDecoration(
                        labelText: 'OTP',
                        hintText: '123456',
                        prefixIcon: const Icon(Icons.password_outlined),
                        errorText: auth.errorMessage,
                      ),
                      onChanged: (_) => auth.clearError(),
                      onSubmitted: (_) => _verify(),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      key: const Key('verifyOtpButton'),
                      onPressed: auth.isVerifyingOtp ? null : _verify,
                      icon: auth.isVerifyingOtp
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.verified_user_outlined),
                      label: Text(
                        auth.isVerifyingOtp ? 'Verifying...' : 'Verify OTP',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _resendSeconds == 0 && !auth.isSendingOtp
                          ? _resend
                          : null,
                      child: Text(
                        auth.isSendingOtp
                            ? 'Sending a new OTP...'
                            : _resendSeconds > 0
                            ? 'Resend OTP in $_resendSeconds seconds'
                            : 'Resend OTP',
                      ),
                    ),
                    TextButton(
                      onPressed: auth.isVerifyingOtp
                          ? null
                          : auth.editPhoneNumber,
                      child: const Text('Use a different mobile number'),
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
