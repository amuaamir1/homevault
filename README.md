# HomeVault

HomeVault is an offline-first Flutter Android application for appliance details, invoices, warranties, support contacts, and maintenance history.

**Current beta: Sprint 10 — v1.12.0+15 (R04)**

## Authentication flow

- New users register with an email address and password.
- Firebase sends an email verification link before HomeVault setup continues.
- After verification, the user creates an account-scoped HomeVault PIN and completes the profile.
- The mobile number is stored as profile/contact information and is not used for authentication.
- While the Firebase session remains active, normal app access uses the HomeVault PIN or biometrics.
- After explicit sign-out, the user signs in again using email and password.
- Forgotten passwords use Firebase password-reset email.
- Forgotten HomeVault PINs require account-password verification before a new PIN can be created.

See `FIREBASE_EMAIL_AUTH_SETUP.md` before running this build.

## Current capabilities

- Add, edit, search, and delete appliances.
- Permanent account-separated local appliance storage.
- Invoice, warranty card, manual, installation, and other document storage.
- Customer support directory with call, email, and website actions.
- Warranty Center, extended warranties, claims, and expiry reminders.
- Service Center with repair history, costs, receipts, reports, and next-service reminders.
- Firebase email authentication and Cloud Firestore user profiles.
- HomeVault PIN, biometric unlock, auto-lock, backup, export, and beta feedback.

## Development checks

```powershell
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter run
```

## Build a release APK

```powershell
flutter build apk --release
```

Output:

```text
build\app\outputs\flutter-apk\app-release.apk
```

HomeVault appliance records and attached files remain in private application storage unless the user creates a backup. Do not uninstall the app or clear Android storage before exporting a backup.
