import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/screens/auth/firebase_setup_required_screen.dart';

void main() {
  testWidgets(
    'startup failure screen keeps technical details out of normal UI',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FirebaseSetupRequiredScreen(
            details: StateError('secret implementation detail'),
          ),
        ),
      );

      expect(find.text('HomeVault could not start'), findsOneWidget);
      expect(find.textContaining('secret implementation detail'), findsNothing);
      expect(find.textContaining('firebase login'), findsNothing);
    },
  );
}
