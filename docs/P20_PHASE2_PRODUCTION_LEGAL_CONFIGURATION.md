# P20.2 — Production Legal URL Configuration

HomeVault production releases use the public Firebase Hosting legal site:

- Privacy Policy: `https://homevault-prod-in-2026-a1.web.app/privacy`
- Terms of Service: `https://homevault-prod-in-2026-a1.web.app/terms`
- Account deletion: `https://homevault-prod-in-2026-a1.web.app/delete-account`
- Support email: `support.homevault1@gmail.com`

## Production build behavior

`scripts/firebase/Build-HomeVault-Production.ps1` now injects these values using Dart defines so the P20.1 **About & Legal** UI opens the production destinations. The script also exposes the same values as process-scoped environment variables during the build and restores the previous environment afterward.

## Release safety gate

`android/app/build.gradle.kts` now requires all four legal configuration values whenever a Gradle release task is requested. Release builds fail if a URL is missing, non-HTTPS, local/development, or placeholder/example content, or if the support email is missing/invalid. Debug/development builds are unaffected.

This works in addition to the existing production Firebase project and signing checks.

## Validation

Run:

```powershell
dart format test\p20_phase2_production_legal_release_contract_test.dart
flutter analyze
flutter test test\p20_phase2_production_legal_release_contract_test.dart
flutter test
```

A later production build should use the production Firebase build workflow rather than a generic `flutter build appbundle --release`.
