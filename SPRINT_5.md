# Sprint 5 — Service and Maintenance History

Version: **1.5.0+6**

## Goal

Make HomeVault the permanent service-history record for every appliance, including repair details, costs, documents, next-service dates, and maintenance reminders.

## Features

- Dedicated Service Center available from the dashboard and Settings.
- Add, edit, search, filter, sort, and delete service records.
- Service statuses: Scheduled, Open, In progress, Completed, and Cancelled.
- Store service date, provider, technician, complaint/ticket number, problem, completed work, replaced parts, cost, payment method, next-service date, and notes.
- Attach a service receipt and service/inspection report.
- Service documents appear in the global Documents vault.
- Track total service cost per appliance and across HomeVault.
- Dashboard counters for service records and services due within 30 days.
- Maintenance reminders use the existing local-notification setup.
- Editing or deleting a service record reschedules or cancels its reminder.
- Tapping a maintenance notification opens the related appliance.
- Service history remains saved after app restart.
- Geyser / Water Heater is included as an appliance category.

## Compatibility

Existing Sprint 1–4 appliance data remains compatible. Records without a `serviceRecords` field load with an empty service history.

No new Flutter package is added. Sprint 5 continues to use:

```yaml
file_picker: 10.3.10
flutter_local_notifications: 22.2.0
flutter_timezone: 5.1.0
```

## Acceptance test

1. Add or open an appliance.
2. Add a service record with a problem description and service charge.
3. Attach a receipt and service report.
4. Set a future next-service date and enable a reminder.
5. Confirm the record appears in Appliance Details and Service Center.
6. Search by provider, ticket number, or appliance name.
7. Test Active, Scheduled, Completed, Cancelled, and Due soon filters.
8. Edit the record and confirm the update persists.
9. Stop and restart the app; verify the record and attachments remain.
10. Delete the record; restart and confirm it stays deleted.
11. Verify the receipt/report appears in Documents and opens successfully.
12. Run `flutter analyze`, `flutter test`, and an Android build.
