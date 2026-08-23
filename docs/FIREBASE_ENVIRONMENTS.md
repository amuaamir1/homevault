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

Production must use a different Firebase project. During P16 Phase 2 the verified project may be added as a `production` alias in `.firebaserc`; `default` and `development` must always remain mapped to `homevault-aamir-india-1701`. Firebase client configuration files remain outside source control.

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


## P16 Phase 2 onboarding

Use `scripts/firebase/Provision-HomeVault-ProductionFirebase.ps1` to create or
connect the dedicated Production Firebase project, register
`com.amuaamir.homevault`, register the release SHA-1 when available, create the
default Firestore database with deletion protection, and write client config to
`C:\Projects\HomeVault-Firebase-Config\production`.

Cloud Storage provisioning remains an explicit Firebase Console step because a
new default Cloud Storage for Firebase bucket requires a Blaze billing plan.
For HomeVault's India-focused deployment, the default recommendation is
`asia-south1` (Mumbai) for Firestore and, unless there is a documented reason
otherwise, the Storage bucket as well.

Production Authentication currently needs Email/Password and Google. The app
contains Apple provider support in its service layer, but the Android sign-in
screen does not expose Apple sign-in, so Apple credentials are not a Phase 2
launch dependency.

After Storage and Authentication are configured in the Firebase Console, run
`scripts/firebase/Finalize-HomeVault-ProductionFirebase.ps1`. It refreshes the
Android config, verifies the Storage bucket, Google OAuth client, release SHA-1,
Firestore, regenerates the external `firebase_options.dart`, deploys the exact
P13 Phase 2 security rules to the explicit Production project, and can run a
temporary Auth/Firestore security smoke test plus a real Production APK build.
