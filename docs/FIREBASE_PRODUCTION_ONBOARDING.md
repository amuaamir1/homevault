# HomeVault Production Firebase onboarding

## Architecture decision

HomeVault uses two Firebase projects:

- Development: `homevault-aamir-india-1701`
- Production: a separate globally unique Firebase project ID chosen during
  P16 Phase 2 onboarding.

The Production project ID is public configuration, not a secret. The Android
client config files are still kept outside source control to preserve the
existing HomeVault source-sharing workflow.

## Recommended Production region

HomeVault targets users in India. The default P16 recommendation is:

- Firestore: `asia-south1` (Mumbai)
- Storage: `asia-south1` (Mumbai), unless a documented latency, compliance, or
  cost requirement leads to a different deliberate choice.

Choose locations carefully before provisioning.

## Phase 2 flow

### 1. Apply and locally validate the P16 Phase 2 tooling

No Firebase cloud resources are created by the Apply script.

### 2. Provision the Production project

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\firebase\Provision-HomeVault-ProductionFirebase.ps1" -ConfirmCreateProject -ConfirmCreateFirestore
```

If `-ProductionProjectId` is omitted, the script prompts for a globally unique
Firebase/Google Cloud project ID.

The provisioning script:

- refuses `homevault-aamir-india-1701`;
- creates the project only with `-ConfirmCreateProject`;
- registers Android package `com.amuaamir.homevault`;
- downloads Production `google-services.json` to
  `C:\Projects\HomeVault-Firebase-Config\production`;
- attempts to determine the release SHA-1 from Gradle `signingReport` without
  reading or printing keystore passwords;
- creates `(default)` Firestore only with `-ConfirmCreateFirestore`;
- enables Firestore deletion protection;
- generates an external Android-only `firebase_options.dart`;
- writes non-secret onboarding state outside the repository;
- does not deploy Production rules yet.

### 3. Complete Firebase Console gates

In the new Production Firebase project:

1. Project Settings > General:
   mark the project environment as **Production**.
2. Link/upgrade the project to the **Blaze** plan.
3. Databases & Storage > Storage:
   create the default bucket.
4. Security > Authentication > Sign-in method:
   enable **Email/Password**.
5. Security > Authentication > Sign-in method:
   enable **Google**, choose the project support email, and save.
6. Project Settings > General > Android app:
   confirm the HomeVault release SHA-1 fingerprint is present.

Do not enable public Firestore or Storage rules.

### 4. Finalize

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\firebase\Finalize-HomeVault-ProductionFirebase.ps1" `
  -ConfirmProjectMarkedProduction `
  -ConfirmBlazeAndStorage `
  -ConfirmAuthConfigured `
  -ConfirmProductionRules `
  -RunLiveSmoke `
  -BuildProductionApk
```

The Production project ID is read from the external onboarding state if it is
not supplied again.

Finalization:

- refreshes Production `google-services.json`;
- requires a Storage bucket;
- requires a Google web OAuth client in the Android config;
- verifies the release SHA-1;
- verifies Firestore;
- regenerates external `firebase_options.dart`;
- validates the project/config pair using the P16 Phase 1 guard;
- deploys only the exact validated P13 Firestore/Storage rules to Production;
- optionally creates a temporary Email/Password user to prove:
  - Production Auth works,
  - owner Firestore access works,
  - cross-user Firestore access is denied,
  - cleanup works;
- optionally builds a real Production APK.

## Remaining manual smoke after finalization

Before marking P16 Phase 2 complete, install the Production APK on a test device
and verify:

- Email/password registration and sign-in.
- Google sign-in.
- Profile save.
- Appliance add/edit.
- Document upload/open/delete.
- Cloud backup creation.
- Beta feedback submission.
- Sign-out/sign-in data persistence.
- No Development users or data appear in Production.
- No Production users or data appear in Development.

## GitHub Production release settings

After Phase 2 is green, use the existing:

`scripts/ci/SETUP_GITHUB_PRODUCTION_FIREBASE_SECRETS.ps1`

to populate:

- `PROD_FIREBASE_OPTIONS_DART_BASE64`
- `PROD_GOOGLE_SERVICES_JSON_BASE64`
- `PRODUCTION_FIREBASE_PROJECT_ID`

Stable releases must continue to use the P16 production build path.
