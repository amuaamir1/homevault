# HomeVault

HomeVault is an offline-first Flutter application for keeping household appliance details, invoices, warranty documents, customer-support contacts, and warranty reminders together.

## Current release

**Sprint 4 — version 1.4.0+5**

### Available features

- Add, edit, search, and delete appliances.
- Persist appliance records locally after restart.
- Attach invoices, warranty cards, manuals, service receipts, installation reports, and other documents.
- Search, filter, edit, replace, open, and delete documents.
- Store and use customer-support phone, email, website, and notes.
- Dedicated Warranty Center with status filters and sorting.
- Standard and extended warranty tracking.
- Warranty terms, coverage notes, claim number, claim status, and manual out-of-warranty control.
- Timezone-aware local warranty reminders.
- Android notification permission and a test-notification action.
- Open the related appliance by tapping its warranty notification.

## Development setup

```powershell
flutter clean
flutter pub get
flutter analyze
flutter test
flutter run
```

Use a complete restart after applying Sprint 4 because notification plugins and Android manifest configuration were added.

## Important dependency note

Keep the document picker pinned to:

```yaml
file_picker: 10.3.10
```

This is the version already proven to work with the Android configuration used by this project.

## Data safety

HomeVault currently stores records and copied documents inside the application's private local storage. Do not uninstall the app or clear its Android storage unless a separate copy of important invoices and warranty documents exists. Backup and restore are planned for a later sprint.

See `SPRINT_4.md` for the complete Sprint 4 test checklist.
