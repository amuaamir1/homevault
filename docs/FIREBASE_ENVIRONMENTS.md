# HomeVault Firebase environments

## P16 architecture

HomeVault uses separate Firebase projects for development and production.

### Development

- Firebase project: `homevault-aamir-india-1701`
- `.firebaserc` aliases both `default` and `development` to this project.
- A bare Firebase CLI command therefore remains pointed at non-production.
- Debug/profile runs use development Firebase configuration.
- A signed internal beta release may use Development only when the build explicitly sets `HOMEVAULT_ALLOW_NON_PROD_RELEASE=true`.

### Production

Production must use a different Firebase project. Its project ID is deliberately not stored in the repository until the project exists, and Firebase client configuration files remain outside source control.

Recommended local configuration location:

`C:\Projects\HomeVault-Firebase-Config\production`

with:

- `firebase_options.dart`
- `google-services.json`

The project ID in both files must match, and the Android app must be registered as `com.amuaamir.homevault`.

## Fail-closed behavior

HomeVault validates the selected Firebase project before initializing Firebase.

A production build must:

1. be a Flutter release build;
2. set `HOMEVAULT_ENV=production`;
3. set `HOMEVAULT_FIREBASE_PROJECT_ID=<production-project-id>`;
4. contain Firebase config for exactly that project;
5. never use `homevault-aamir-india-1701`.

Android release configuration performs the same project-ID check at Gradle configuration time.

## Production build

Use `scripts/firebase/Build-HomeVault-Production.ps1`. It validates the external production Firebase config, temporarily activates it, builds with the required Dart defines, and restores the local development configuration in a `finally` block.

## Rules deployment

Use `scripts/firebase/Deploy-HomeVault-Firebase-Rules.ps1`.

The script always passes an explicit `--project` to Firebase CLI. Production additionally requires `-ConfirmProduction`, and the P13 Phase 2 Firestore/Storage rule hashes must still match the validated security baseline.

## GitHub Actions

Developer release builds continue to use the existing Development Firebase secrets, but now explicitly declare that they are non-production release builds.

A non-prerelease manual release is reserved for Production and requires:

- GitHub secret `PROD_FIREBASE_OPTIONS_DART_BASE64`
- GitHub secret `PROD_GOOGLE_SERVICES_JSON_BASE64`
- GitHub variable `PRODUCTION_FIREBASE_PROJECT_ID`

Use `scripts/ci/SETUP_GITHUB_PRODUCTION_FIREBASE_SECRETS.ps1` after the production Firebase project and client files are ready.

## P16 remaining work after Phase 1

Phase 1 installs the architecture and guards. The production Firebase project is intentionally not created or guessed by the patch.

Next:

1. create the dedicated Production Firebase project;
2. mark it as Production in Firebase Project Settings;
3. register Android package `com.amuaamir.homevault`;
4. enable and configure Authentication providers used by HomeVault;
5. create Firestore/Storage in the appropriate region;
6. deploy the already-validated HomeVault rules with the explicit production deployment script;
7. store production client config outside the repository;
8. configure production GitHub secrets;
9. run production smoke verification before allowing stable releases.
