# HomeVault

HomeVault is a Flutter Android application that keeps appliance details, warranty dates, invoice files, warranty-card files, and customer-support contacts in one place.

## Current sprint: 0.2 — Document attachments

This build adds:

- Invoice number/reference field
- Invoice PDF or image upload
- Warranty provider and card/reference fields
- Warranty-card PDF or image upload
- Secure copies of selected files inside the app documents directory
- File-size limit of 15 MB per attachment
- PDF, JPG, JPEG, and PNG support
- Document list in the Documents tab
- Open-document actions from the appliance details and Documents screens
- File replacement and removal before saving
- Attached-file cleanup when an appliance is deleted
- Keyboard dismissal while scrolling the form

## Important limitation

Appliance records are still stored in memory. The selected files are copied into app storage, but the appliance-to-document links will be lost after a full app restart until Sprint 1 adds persistent local data storage.

Do not use this build as the only copy of an important invoice yet.

## Run in VS Code

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Because native plugins were added, stop the current app and run `flutter run` again. A normal hot reload is not enough after adding plugin dependencies.

## Test the new feature

1. Open **Add appliance**.
2. Enter an appliance name.
3. Scroll to **Purchase and warranty**.
4. Tap **Choose file** under Invoice file.
5. Select a PDF or image.
6. Tap **Choose file** under Warranty card file.
7. Save the appliance.
8. Open the appliance details and tap each attachment.
9. Open the Documents tab and verify both files are listed.

## Next sprint

Sprint 1 will store appliance records and document metadata permanently so everything remains after closing and reopening the app.
