import 'package:flutter/material.dart';

class HomeVaultAccessibleForm extends StatelessWidget {
  const HomeVaultAccessibleForm({
    super.key,
    required this.formKey,
    required this.child,
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
  });

  final GlobalKey<FormState> formKey;
  final Widget child;
  final AutovalidateMode autovalidateMode;

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Form(
        key: formKey,
        autovalidateMode: autovalidateMode,
        child: child,
      ),
    );
  }
}

class HomeVaultFormValidationSummary extends StatelessWidget {
  const HomeVaultFormValidationSummary({
    super.key,
    required this.visible,
    this.message =
        'Check the highlighted fields. Correct the errors, then try again.',
  });

  final bool visible;
  final String message;

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      key: const ValueKey('p19FormValidationSummary'),
      container: true,
      liveRegion: true,
      label: message,
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
