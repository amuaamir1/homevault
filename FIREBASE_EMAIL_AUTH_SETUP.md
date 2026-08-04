# Firebase Email Authentication Setup

HomeVault Sprint 10 replaces mobile SMS OTP sign-in with Firebase email/password authentication and email verification.

## 1. Enable Email/Password authentication

1. Open Firebase Console.
2. Select the HomeVault project.
3. Open **Authentication**.
4. Open **Sign-in method**.
5. Enable **Email/Password**.
6. Save the change.

The app uses normal Email/Password accounts. It sends a Firebase verification email immediately after registration.

## 2. Configure email templates

In **Authentication → Templates**, review these templates:

- Email address verification
- Password reset

Recommended sender name: `HomeVault`

Recommended verification subject:

```text
Verify your HomeVault email
```

Recommended password-reset subject:

```text
Reset your HomeVault password
```

## 3. Keep Cloud Firestore enabled

HomeVault stores profiles in:

```text
users/{firebaseUid}
```

The existing `firestore.rules` restricts each profile to the matching authenticated Firebase UID.

## 4. Existing phone-auth beta users

Users who are still signed in through the old phone-auth build are shown an **Upgrade your HomeVault login** screen. They can link an email and password to the same Firebase UID, preserving their profile and account-scoped local data.

An old user who signs out before upgrading cannot use the removed mobile OTP screen. Migrate active beta users before disabling Phone authentication in Firebase Console.

## 5. Validate locally

```powershell
cd C:\Projects\homeVaultApp
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter run
```

Registration test flow:

1. Open **Register**.
2. Enter an unused email and a password containing at least eight characters, uppercase, lowercase, and a number.
3. Tap **Register**.
4. Open the verification email and verify the address.
5. Return to HomeVault and tap **I verified my email**.
6. Create the HomeVault PIN.
7. Complete the profile, including mobile number and Indian service address.
8. Sign out and confirm that email/password login works.
9. Close and reopen the app without signing out and confirm that PIN login is shown.
