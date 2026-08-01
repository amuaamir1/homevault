# HomeVault

HomeVault is an offline-first Flutter Android application for appliance details, invoices, warranties, support contacts, and maintenance history.

**Current build: Sprint 5 — version 1.5.0+6**

## Current capabilities

- Add, edit, search, and delete appliances.
- Permanent local appliance storage.
- Invoice, warranty card, manual, installation, and other document storage.
- Customer support directory with call, email, and website actions.
- Warranty Center, extended warranties, claims, and expiry reminders.
- Service Center with repair history, costs, receipts, reports, and next-service reminders.
- Dashboard warranty and maintenance counters.
- Geyser / Water Heater appliance category.

## Development checks

```powershell
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter run
```

## Build an APK

```powershell
flutter build apk --release
```

Output:

```text
build\app\outputs\flutter-apk\app-release.apk
```

HomeVault stores data in private application storage. Do not uninstall the app or clear its Android storage until backup and restore is implemented.

See `SPRINT_5.md` for the Sprint 5 acceptance test.
