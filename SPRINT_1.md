# Sprint 1 — Permanent appliance storage

## Goal
Keep appliance records, support contacts, warranty information, and document references after the app is closed or restarted.

## Delivered
- Local JSON data repository inside the app's private documents directory.
- Startup loading and retry states.
- Persistent add, update, and delete operations.
- Edit appliance action on the details screen.
- Delete confirmation before removing a record and its document folder.
- JSON serialization for appliance and stored-document models.
- In-memory repository for fast automated tests.
- Automated tests for serialization, persistence, update, and delete.

## Storage location
The app writes appliance metadata to its private application documents directory under:

`homevault/data/appliances.json`

Invoice and warranty files continue to be stored under:

`homevault/appliances/<appliance-id>/`

Android manages the actual root path. The data remains available after normal app restarts, but Android removes it when the app is uninstalled or its storage is cleared.

## Sprint 1 acceptance test
1. Add an appliance with invoice and warranty details.
2. Fully stop the app.
3. Start the app again and confirm the appliance is present.
4. Edit its name or model number.
5. Restart again and confirm the change remains.
6. Delete the appliance, confirm the warning, restart, and confirm it remains deleted.
