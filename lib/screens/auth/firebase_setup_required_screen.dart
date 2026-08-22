import 'package:flutter/material.dart';

import '../../services/homevault_error_message.dart';

class FirebaseSetupRequiredScreen extends StatelessWidget {
  const FirebaseSetupRequiredScreen({super.key, this.details});

  final Object? details;

  @override
  Widget build(BuildContext context) {
    final message = details == null
        ? 'HomeVault could not start its cloud services. Close the app and try again.'
        : friendlyHomeVaultError(
            details!,
            fallback:
                'HomeVault could not start its cloud services. Check your connection and try again.',
          );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.cloud_off_outlined,
                    size: 72,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'HomeVault could not start',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  const Text(
                    'Your data has not been changed. If the problem continues, check your internet connection and reopen HomeVault.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
