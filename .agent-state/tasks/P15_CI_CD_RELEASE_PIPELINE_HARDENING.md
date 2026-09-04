# P15 — CI/CD & Release Pipeline Hardening

Status: **IMPLEMENTED IN CODE / MANUAL REPOSITORY GATES PENDING**

This task records the P15 hardening increment applied to the existing HomeVault CI/CD pipeline. Existing development validation, developer release, manual release, Firebase environment isolation, signing, GitHub Release publishing, and Google Drive publishing are preserved.

## Implemented

- Exact `FLUTTER_VERSION` (`x.y.z`) validation while retaining the GitHub repository variable as the single CI version source.
- Tracked-source secret/generated-file hygiene gate before generated Firebase/signing files are restored.
- `pubspec.lock` existence/tracking/drift validation after dependency restoration.
- Checked-in `pubspec.yaml` ↔ `AppBuildInfo` version/build/release consistency checks.
- Signed APK verification with Android `apksigner`; APK package/version metadata is additionally checked when `apkanalyzer` is available.
- Stable manual releases build a signed AAB and verify its JAR signature using `jarsigner`.
- SHA-256 per-artifact checksum files plus aggregate `SHA256SUMS.txt`.
- Machine-readable `release-manifest.json` with non-secret build provenance.
- Generated `RELEASE_NOTES.md` based on Git history since the latest HomeVault tag.
- Explicit `FINAL RELEASE GATE` before workflow artifact, Google Drive, or GitHub Release publishing.
- Privacy-safe failure diagnostics uploaded only on workflow failure.
- Cleanup of restored signing and Firebase files using `if: always()`.
- Local P15 audit: `scripts/ci/Test-HomeVault-P15.ps1`.
- Optional, dry-run-by-default GitHub branch-protection helper: `scripts/ci/Set-HomeVault-BranchProtection.ps1`.
- P15 Flutter contract tests: `test/p15_ci_release_contract_test.dart`.

## Release artifact structure

Developer beta release:

- HomeVault Beta APK
- `<apk>.sha256.txt`
- `SHA256SUMS.txt`
- `release-manifest.json`
- `RELEASE_NOTES.md`

Stable manual release:

- HomeVault Release APK
- HomeVault Release AAB
- per-artifact SHA-256 files
- `SHA256SUMS.txt`
- `release-manifest.json`
- `RELEASE_NOTES.md`

## Expected GitHub configuration

Repository variables:

- `FLUTTER_VERSION` — exact `x.y.z` Flutter SDK version.
- `PRODUCTION_FIREBASE_PROJECT_ID` — required by stable manual production releases.
- `GDRIVE_RELEASE_DIR` — optional; existing default remains available.

Development Firebase secrets:

- `FIREBASE_OPTIONS_DART_BASE64`
- `GOOGLE_SERVICES_JSON_BASE64` (release workflows)

Production Firebase secrets:

- `PROD_FIREBASE_OPTIONS_DART_BASE64`
- `PROD_GOOGLE_SERVICES_JSON_BASE64`

Android signing secrets:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_STORE_PASSWORD`
- `ANDROID_KEY_PASSWORD`
- `ANDROID_KEY_ALIAS`

Release publishing secret:

- `GDRIVE_RCLONE_CONFIG_BASE64`

GitHub's generated `github.token` remains used for GitHub Release/tag operations.

## Manual actions still required

1. Run the P15 local audit and Flutter validation.
2. Push the patch on a branch and confirm all GitHub Actions workflows pass.
3. Configure/confirm required branch protection checks for `develop` and `main`. The helper script is dry-run by default and never changes remote protection unless `-Apply` is explicitly supplied.
4. Execute a real developer prerelease and confirm APK signature/integrity metadata and publishing.
5. Execute an authorized manual stable release when appropriate and confirm APK/AAB signing/integrity metadata.

P15 must remain open until those manual repository/release gates are confirmed.

## Security / privacy impact

The hardening adds early source-secret detection, avoids printing secret values, keeps diagnostics restricted to tool/repository metadata, verifies Android signatures before publishing, and removes restored signing/Firebase files at workflow completion. Existing P13 and P16 controls are not weakened.
