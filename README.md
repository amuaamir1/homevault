# HomeVault

HomeVault is a Flutter Android application for keeping appliance details, warranty information, invoices, manuals, service records, and customer-support contacts in one place.

## Current milestone: Sprint 3

Implemented:
- Dashboard and five-section navigation
- Add, search, view, edit, and delete appliances
- Permanent offline appliance storage
- Warranty-status calculation
- Invoice and warranty-card attachments
- Multi-document vault for manuals, receipts, reports, and other files
- Document search, category filters, edit, replace, open, and delete actions
- Customer support center with provider details and notes
- Direct phone, email, and website actions
- Support search and contact-method filters
- Startup loading and storage error handling
- Automated widget, serialization, migration, persistence, and support-action tests

## Run locally

```powershell
flutter clean
flutter pub get
flutter analyze
flutter test
flutter run
```

The project intentionally keeps `file_picker: 10.3.10` because it works with the Android/Kotlin configuration currently used by the project. Sprint 3 adds the official `url_launcher` plugin for phone, email, and browser actions.

See `SPRINT_3.md` for the acceptance test and emulator notes.
