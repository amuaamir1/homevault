import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/services/homevault_error_presenter.dart';

void main() {
  testWidgets('technical Firebase error is translated before display', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showHomeVaultError(
                context,
                FirebaseException(
                  plugin: 'cloud_firestore',
                  code: 'permission-denied',
                  message: 'raw technical details',
                ),
              ),
              child: const Text('Show error'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show error'));
    await tester.pump();

    expect(
      find.text(
        'HomeVault does not have permission to access this data. Sign in again and try once more.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('permission-denied'), findsNothing);
    expect(find.textContaining('raw technical details'), findsNothing);
  });

  testWidgets('new HomeVault error replaces the previous SnackBar', (
    tester,
  ) async {
    late BuildContext presenterContext;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              presenterContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    showHomeVaultError(
      presenterContext,
      StateError('first technical detail'),
      fallback: 'First friendly error.',
    );
    await tester.pump();

    showHomeVaultError(
      presenterContext,
      StateError('second technical detail'),
      fallback: 'Second friendly error.',
    );
    await tester.pump();

    expect(find.text('Second friendly error.'), findsOneWidget);
    expect(find.text('First friendly error.'), findsNothing);
  });

  testWidgets('retry action is presented consistently', (tester) async {
    var retried = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showHomeVaultError(
                context,
                StateError('download failed'),
                fallback: 'The document could not be prepared right now.',
                actionLabel: 'Retry',
                onAction: () => retried = true,
              ),
              child: const Text('Show retry'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show retry'));
    await tester.pump();

    expect(find.text('Retry'), findsOneWidget);

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.action?.label, 'Retry');
    snackBar.action!.onPressed();
    await tester.pump();

    expect(retried, isTrue);
  });
}
