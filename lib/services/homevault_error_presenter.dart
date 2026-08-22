import 'package:flutter/material.dart';

import 'homevault_error_message.dart';

/// Presents operational HomeVault failures consistently throughout the app.
///
/// Error SnackBars replace any currently queued SnackBars so repeated failures
/// do not build up into a stale message queue.
void showHomeVaultError(
  BuildContext context,
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
  String? actionLabel,
  VoidCallback? onAction,
}) {
  if (!context.mounted) return;

  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Text(friendlyHomeVaultError(error, fallback: fallback)),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 6),
      action: actionLabel != null && onAction != null
          ? SnackBarAction(label: actionLabel, onPressed: onAction)
          : null,
    ),
  );
}
