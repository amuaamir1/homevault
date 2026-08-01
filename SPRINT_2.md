# Sprint 2 — Document vault

## Goal
Turn the basic invoice and warranty attachments into a searchable appliance document vault.

## Delivered
- Multiple documents can be attached to every appliance.
- Supported document categories:
  - Invoice
  - Warranty card
  - User manual
  - Service receipt
  - Installation report
  - Other document
- Add documents from the Documents tab or an appliance details screen.
- Store a document title, reference number, and notes.
- Search by appliance, title, filename, or reference number.
- Filter the vault by document category.
- Open files using an installed Android PDF or image application.
- Edit document metadata.
- Replace an attached file while keeping the same document record.
- Delete an individual document with confirmation.
- Existing Sprint 0.2 invoice and warranty files are migrated automatically.
- Document records and metadata remain available after an app restart.
- Automated tests cover migration, serialization, add, update, delete, and vault display.

## Data migration
The appliance storage schema is now version 2. Existing `invoiceDocument` and
`warrantyDocument` records are retained. Missing document IDs and categories are
created while the existing file paths remain unchanged.

## Sprint 2 acceptance test
1. Open an existing appliance and confirm its invoice and warranty card remain available.
2. Open Documents and tap **Add document**.
3. Select an appliance and add a user manual PDF or image.
4. Enter a title and reference, then save.
5. Search for the title or reference.
6. Filter by **User manual**.
7. Open the document.
8. Edit the title and save.
9. Replace the file and confirm the replacement opens.
10. Fully stop and restart the app and confirm the document remains.
11. Delete the document, restart the app, and confirm it remains deleted.

## Current limitation
Files are stored only in the app's private local storage. Uninstalling the app or
clearing Android app data removes them. Backup and restore will be delivered in a
later sprint.
