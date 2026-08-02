# HomeVault Firebase Phone Authentication Setup

HomeVault Android application ID:

```text
com.amuaamir.homevault
```

## 1. Create or select a Firebase project

Open Firebase Console and create/select the project that will serve the HomeVault India beta.

## 2. Install the command-line tools

From PowerShell:

```powershell
npm install -g firebase-tools
firebase login
dart pub global activate flutterfire_cli
```

## 3. Configure this Flutter project

From the HomeVault project folder:

```powershell
cd C:\Projects\homeVaultApp
flutter pub get
flutterfire configure
```

Select the Firebase project and Android platform. Confirm the Android package name is:

```text
com.amuaamir.homevault
```

The FlutterFire CLI should create/update Firebase configuration files and the Android Google Services configuration.

## 4. Enable mobile-number authentication

In Firebase Console:

```text
Authentication → Sign-in method → Phone → Enable
```

For emulator testing, add a Firebase test phone number and a fixed six-digit test OTP under the Phone provider settings. Use a Google Play-enabled emulator image.

## 5. Add Android certificate fingerprints

Add both debug and release SHA fingerprints to the Firebase Android app.

Debug fingerprints:

```powershell
cd C:\Projects\homeVaultApp\android
.\gradlew signingReport
```

Release fingerprint from the HomeVault keystore:

```powershell
& $keytool -list -v `
  -keystore "$env:USERPROFILE\homevault-release.jks" `
  -alias homevault
```

Copy the SHA-1 fingerprint into:

```text
Firebase Console → Project settings → General → Your apps → Android app
```

After adding fingerprints, download the refreshed `google-services.json` when prompted or run `flutterfire configure` again.

## 6. Create Cloud Firestore

In Firebase Console:

```text
Firestore Database → Create database
```

Choose a production database location appropriate for the India beta.

Deploy the included rules using Firebase CLI:

```powershell
firebase init firestore
firebase deploy --only firestore:rules
```

When asked for the rules file, use:

```text
firestore.rules
```

The included rules only allow an authenticated user to access their own `users/{uid}` profile document.

## 7. Run validation

```powershell
cd C:\Projects\homeVaultApp
flutter clean
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter run
```

## 8. Test the complete flow

1. Enter a 10-digit Indian mobile number.
2. Receive or enter the configured test OTP.
3. Create the profile with name, address, State/UT, city, and six-digit PIN code.
4. Create a 4-to-8-digit local app PIN or choose Skip for now.
5. Confirm the dashboard displays `Welcome <first name>`.
6. Open Settings → My profile and update the address.
7. Open Settings → Security and create/change/remove the local PIN.
8. Sign out and sign in again using mobile OTP.

## Important beta limitation

Firebase stores the authenticated account and profile. Appliance records and attached files remain local to the Android device. Signing in on another phone does not automatically copy appliance data; use HomeVault Backup and Restore.
