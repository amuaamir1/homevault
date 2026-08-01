# Sprint 4 — Warranty Center and Reminders

## Goal

Make warranty information easy to manage and notify the user before an appliance warranty expires.

## Features delivered

- Dedicated Warranty Center reachable from the dashboard and Settings.
- Warranty status filters: All, Active, Expiring soon, Expired, and No date.
- Sorting by expiry date, appliance name, or recently added.
- Search by appliance, brand, provider, reference, or claim number.
- Days remaining and effective warranty expiry calculation.
- Extended warranty provider, reference, and expiry date.
- Warranty terms, coverage, and exclusions.
- Warranty claim number and status tracking.
- Manual out-of-warranty status for voided or early-ended coverage.
- Per-appliance reminder toggle.
- Reminder choices: 7, 14, 30, 60, or 90 days before expiry.
- Android notification permission flow.
- Local, timezone-aware scheduled notifications.
- Reminder rescheduling when an appliance is added or edited.
- Reminder cancellation when an appliance is deleted.
- Reminder restoration after device restart or application update.
- Test-notification button for quick physical-device validation.
- Tapping a warranty notification opens the related appliance when available.
- Backward-compatible persistence for existing Sprint 1–3 data.
- Unit and widget tests for warranty calculations and reminder scheduling.

## Important behavior

- HomeVault uses the later of the standard and extended warranty dates as the effective expiry date.
- `Expiring soon` means 30 days or fewer remain.
- Notifications are scheduled at approximately 9:00 AM local device time.
- Inexact Android scheduling is used, so the notification may not appear at the exact second and no exact-alarm permission is requested.
- If the selected reminder date has already passed, HomeVault does not schedule an old reminder. Edit the appliance and choose a shorter reminder period or a future warranty date.
- Notification permission must be enabled on Android 13 or newer.

## Android configuration added

- `POST_NOTIFICATIONS`
- `RECEIVE_BOOT_COMPLETED`
- Scheduled notification receiver
- Boot receiver
- Java 17 core-library desugaring
- Multidex support

## Dependencies

```yaml
flutter_local_notifications: 22.2.0
flutter_timezone: 5.1.0
timezone: 0.11.1
```

The working document-picker version remains:

```yaml
file_picker: 10.3.10
```

## Verification checklist

1. Run `flutter analyze` and confirm no issues.
2. Run `flutter test` and confirm all tests pass.
3. Open Warranty Center from the Home dashboard.
4. Enable notification permission.
5. Tap **Send test notification**.
6. Add or edit an appliance with a future warranty expiry date.
7. Enable its reminder and choose a reminder period.
8. Confirm the appliance appears in the correct status filter.
9. Close and reopen HomeVault and confirm warranty details remain.
10. Edit the warranty expiry and confirm the scheduled reminder count refreshes.
11. Delete the appliance and confirm its reminder is cancelled.

## Known limitations

- Warranty reminders are local to this device and are removed if HomeVault is uninstalled or its data is cleared.
- Some manufacturers restrict background activity. The user may need to allow notifications and unrestricted battery usage for reliable delivery.
- Backup and restore are planned for a later sprint.
