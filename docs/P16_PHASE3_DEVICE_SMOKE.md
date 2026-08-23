# HomeVault P16 Phase 3 - Production Device Smoke

Use a Production release APK installed without clearing app data when validating retained local PIN state.

## Acceptance checks

1. **Email/password + PIN**
   - Explicit Email/password sign-in opens HomeVault directly.
   - The PIN screen does not appear or flash after successful account authentication.
   - A later app launch while still signed in requires the existing PIN/biometric.

2. **Google Sign-In**
   - Explicit Google sign-in opens HomeVault directly.
   - A later app launch requires the existing PIN/biometric.

3. **Document Vault**
   - Upload a small valid PDF or image.
   - Confirm the document appears and opens.
   - Delete it and confirm removal without Storage permission errors.

4. **Cloud backup**
   - Create a manual cloud backup.
   - Confirm the backup-history entry appears and the operation succeeds.

5. **Beta feedback**
   - Submit a short Production feedback entry.
   - Confirm the submission succeeds without exposing technical errors.

6. **Persistence**
   - Add or modify a harmless test record.
   - Force-stop/relaunch and confirm it persists.

7. **Production isolation**
   - Confirm Production test data exists only in `homevault-prod-in-2026-a1`.
   - Confirm the same test data is absent from `homevault-aamir-india-1701`.

## Record the result

Example after all checks pass:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\firebase\Record-HomeVault-P16-Phase3-Device-Smoke.ps1" `
  -EmailPasswordPinFlow PASS `
  -GoogleSignIn PASS `
  -DocumentVault PASS `
  -CloudBackup PASS `
  -BetaFeedback PASS `
  -Persistence PASS `
  -ProductionIsolation PASS
```

Reports are written under `C:\Projects\HomeVault-Test-Reports`.
