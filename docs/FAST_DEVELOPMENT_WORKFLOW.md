# HomeVault Fast Development Workflow

This workflow is designed to reduce repeated patch/analyze/hotfix cycles.

## 1. Create one fresh sanitized baseline

From the HomeVault project:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Create-HomeVault-Safe-Zip.ps1"
```

Upload the generated ZIP from:

`C:\Projects\HomeVault-Safe-Zips\`

Use that ZIP as the authoritative baseline for one complete development batch.

## 2. Develop a whole feature/phase at once

Prefer:

`fresh source -> complete feature -> all related tests -> one patch`

Avoid one-file-at-a-time patching when the changes belong to the same feature.

Patch installers should normally contain complete changed files based on the
uploaded baseline instead of PowerShell string replacements.

## 3. Run one validation command

### Quick validation

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\HomeVault-Validate.ps1" -Mode Quick
```

Quick mode runs:

- Flutter version check
- `flutter pub get`
- Dart format check
- `flutter analyze`
- any explicitly supplied targeted tests

### Quick validation with feature tests

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\HomeVault-Validate.ps1" -Mode Quick -Tests "test\homevault_error_telemetry_test.dart;test\technical_error_leakage_test.dart"
```

### Full validation

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\HomeVault-Validate.ps1" -Mode Full
```

Full mode adds the complete `flutter test` suite.

### Full validation plus debug APK compilation

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\HomeVault-Validate.ps1" -Mode Full -BuildDebug
```

## 4. Send one log instead of individual errors

Every validation run writes one report under:

`C:\Projects\HomeVault-Test-Reports\`

If validation fails, upload the newest log to ChatGPT. The goal is to fix all
reported failures together in one consolidated hotfix.

## 5. GitHub automatically validates development branches

`.github/workflows/development-validation.yml` runs formatting, analyze and the
full Flutter test suite for development pushes and pull requests.

It restores only `lib/firebase_options.dart` from the existing
`FIREBASE_OPTIONS_DART_BASE64` secret. It does not require Android signing and
does not publish a release.

The existing developer/manual release workflows remain separate.

## Recommended batch lifecycle

1. Create/upload sanitized source.
2. Develop one complete roadmap phase or feature.
3. Apply one changed-files patch.
4. Run `HomeVault-Validate.ps1 -Mode Full` with targeted tests if useful.
5. If it fails, upload the single validation log.
6. Apply one consolidated hotfix.
7. Perform only the manual emulator/Firebase checks that automation cannot
   reliably cover.
8. Mark the phase complete.
