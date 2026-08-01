# Sprint 0.2 — Invoice and warranty attachments

## User story

As an appliance owner, I want to attach the invoice and warranty card to an appliance so I can retrieve them when support or warranty service is needed.

## Acceptance criteria

- A user can select one invoice file.
- A user can select one warranty-card file.
- Supported types are PDF, JPG, JPEG, and PNG.
- A file larger than 15 MB is rejected with a clear message.
- The selected file name and size appear before saving.
- A selected file can be replaced or removed.
- Saved attachments appear in appliance details.
- Saved attachments appear in the Documents tab.
- Tapping an attachment asks Android to open it in a compatible app.
- Deleting an appliance removes its stored attachment files.
- `flutter analyze` should report no issues in the developer environment.

## Deferred to Sprint 1

- Permanent storage of appliance records and document metadata
- Editing an existing appliance
- Multiple invoices or warranty documents per appliance
- In-app PDF/image preview
- Cloud backup
