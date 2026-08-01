# HomeVault

HomeVault is a Flutter Android application for keeping appliance details, warranty information, invoices, manuals, service records, and customer-support contacts in one place.

## Current milestone: Sprint 2

Implemented:
- Dashboard and five-section navigation
- Add, search, view, edit, and delete appliances
- Permanent offline appliance storage
- Warranty-status calculation
- Invoice and warranty-card attachments
- Multi-document vault for manuals, receipts, reports, and other files
- Document search, category filters, edit, replace, open, and delete actions
- Support directory
- Startup loading and storage error handling
- Automated widget, serialization, migration, and persistence tests

## Run locally

```powershell
flutter clean
flutter pub get
flutter analyze
flutter test
flutter run
```

The project intentionally keeps `file_picker: 10.3.10` because it works with the Android/Kotlin configuration currently used by the project.

See `SPRINT_2.md` for the acceptance test and data-migration notes.
