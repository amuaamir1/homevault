HomeVault feedback admin test-safety fix

Cause:
The Settings screen creates FirebaseFeedbackAdminRepository while the app shell
is being built. Widget tests do not initialize Firebase, so
FirebaseFirestore.instance throws [core/no-app] even when the test is about
another screen such as Reports.

Fix:
- The optional admin-access check now returns false when the UID is empty.
- Firebase/admin-check failures are caught and the Feedback dashboard tile is
  simply hidden.
- Production behavior is unchanged when Firebase is initialized normally.

Run:
dart format lib\screens\settings\settings_screen.dart
flutter analyze
flutter test test\widget_test.dart --plain-name "reports screen shows current portfolio insights"
flutter test
