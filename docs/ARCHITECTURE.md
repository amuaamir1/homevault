# HomeVault Architecture

## Current layers

- `lib/models`: Domain objects such as `Appliance`.
- `lib/state`: App-wide state and the temporary in-memory repository.
- `lib/screens`: Feature screens grouped by responsibility.
- `lib/widgets`: Reusable presentation components.
- `lib/theme`: Shared visual design tokens and Material theme.

## State flow

`HomeVaultApp` owns one `ApplianceStore`. `AppScope` exposes that store to screens using Flutter's built-in `InheritedNotifier`. The store notifies the dashboard, appliance list, document references, and support directory whenever appliance data changes.

## Next persistence design

Replace the internal list in `ApplianceStore` with a repository abstraction:

- `ApplianceRepository`
- `DocumentRepository`
- Local database implementation
- File-storage service

The UI should continue using the store/controller layer so database changes do not leak into widgets.

## Suggested document model

Each document should have:

- ID
- Appliance ID
- Type: invoice, warranty, manual, photo, other
- Display name
- Local file path
- MIME type
- Created date
- Optional invoice number
- Optional notes
