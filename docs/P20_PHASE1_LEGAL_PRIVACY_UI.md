# P20.1 — Google Play Legal & Privacy UI

Status: IMPLEMENTED BY PATCH — production URLs still required before release.

## What this phase adds

HomeVault Settings now exposes an **About & Legal** destination containing:

- Privacy Policy
- Terms of Service
- Account & Data Deletion
- Contact Support
- Open-source licenses
- App version/build/release information

The existing destructive account-deletion implementation is reused rather than duplicated.

## Production configuration

P20.1 deliberately does **not** invent public legal URLs or support addresses.

Configure the real values at build time with:

```text
HOMEVAULT_PRIVACY_POLICY_URL
HOMEVAULT_TERMS_OF_SERVICE_URL
HOMEVAULT_ACCOUNT_DELETION_URL
HOMEVAULT_SUPPORT_EMAIL
```

All web URLs must be public HTTPS URLs. Localhost and `.local` hosts are rejected.

Example build shape (replace every example value with the real production value):

```powershell
flutter build appbundle `
  --dart-define=HOMEVAULT_PRIVACY_POLICY_URL=https://YOUR-DOMAIN.example/privacy `
  --dart-define=HOMEVAULT_TERMS_OF_SERVICE_URL=https://YOUR-DOMAIN.example/terms `
  --dart-define=HOMEVAULT_ACCOUNT_DELETION_URL=https://YOUR-DOMAIN.example/delete-account `
  --dart-define=HOMEVAULT_SUPPORT_EMAIL=support@YOUR-DOMAIN.example
```

Do not use those example values for a Play production release.

## P20.2 follow-up

The next phase must create and publish the real public pages and configure the final support contact. A production release gate should then reject builds where these values are missing or invalid.

## Validation

Run:

```powershell
dart format lib test
flutter analyze
flutter test test\p20_phase1_legal_ui_test.dart
flutter test
```
