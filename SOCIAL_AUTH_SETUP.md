# HomeVault Google and Apple Sign-In Setup

This patch adds the login-screen UI and Firebase authentication code for:

- Email/password sign-in and registration
- Google sign-in/registration
- Apple sign-in/registration

The Android application ID is:

```text
com.amuaamir.homevault
```

## 1. Google sign-in configuration

### Add Android SHA fingerprints

From the project:

```powershell
cd C:\Projects\homeVaultApp\android

.\gradlew signingReport |
  Select-String -Pattern "Variant:|Config:|Store:|Alias:|SHA1:|SHA-256:"
```

Add the debug and release SHA-1/SHA-256 values in:

```text
Firebase Console
→ Project settings
→ General
→ Your apps
→ HomeVault Android app
→ SHA certificate fingerprints
```

### Enable Google provider

```text
Firebase Console
→ Authentication
→ Sign-in method
→ Google
→ Enable
→ Select project support email
→ Save
```

### Refresh google-services.json

Download the updated `google-services.json` and replace:

```text
C:\Projects\homeVaultApp\android\app\google-services.json
```

The updated file must include an OAuth client with client type `3` (web client).
You can check without showing client secrets:

```powershell
Select-String `
  -Path .\android\app\google-services.json `
  -Pattern '"client_type"\s*:\s*3'
```

Do not commit or share `google-services.json` unless your repository policy
explicitly allows it.

## 2. Apple sign-in configuration

Apple sign-in requires an active Apple Developer Program membership.

In the Apple Developer portal, create/configure:

1. An App ID with **Sign in with Apple** enabled.
2. A Services ID for the Android/web OAuth flow.
3. A Sign in with Apple private key.
4. The Firebase OAuth return URL as an allowed return URL.

The Firebase return URL normally has this format:

```text
https://<YOUR_FIREBASE_PROJECT_ID>.firebaseapp.com/__/auth/handler
```

Then enable Apple in:

```text
Firebase Console
→ Authentication
→ Sign-in method
→ Apple
```

Enter the Apple Services ID, Team ID, Key ID, and private key requested by
Firebase.

The Apple button can be displayed before this configuration is complete, but
sign-in will fail until the provider is fully configured.

## 3. Apply package changes

The patch adds:

```yaml
google_sign_in: 7.2.0
```

Run:

```powershell
cd C:\Projects\homeVaultApp
flutter clean
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter run
```

## 4. Test accounts safely

For initial testing, use dedicated beta accounts.

- A new Google or Apple user receives a Firebase UID and a HomeVault profile/PIN
  is created for that UID.
- A Google account using the same verified email as an existing Firebase
  email/password account may be treated by Firebase as the same trusted account.
- Apple users choosing **Hide My Email** can receive an Apple relay email and may
  therefore create a separate Firebase account from an existing email/password
  account.

Do not delete old Firebase users while testing. HomeVault data and the local PIN
are scoped to the Firebase UID.

## 5. Expected login screen

```text
HomeVault

Sign in to HomeVault
Use your verified email and password.

Email address
Password
                         Forgot password?

[ Sign in ]

──────────── OR CONTINUE WITH ────────────

[ G  Continue with Google ]
[ Apple  Continue with Apple ]

Don't have an account yet? Register
```
