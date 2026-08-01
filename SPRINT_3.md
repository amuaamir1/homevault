# Sprint 3 — Customer support center

## Goal
Make HomeVault a practical support directory where users can quickly find and use the customer-care details saved for each appliance.

## Delivered
- Dedicated support provider and support-notes fields for every appliance.
- Existing appliance data migrates safely; new support fields default to empty.
- Search support contacts by appliance, category, brand, model, serial number, provider, phone, email, website, or notes.
- Filter support contacts by phone, email, or website availability.
- Start a phone call using the device dialer.
- Compose a support email with the appliance name, brand, model, and serial number prefilled.
- Open the saved support website in the device browser.
- Copy phone numbers, email addresses, and websites.
- Add or edit support details directly from the Support tab.
- Direct support actions are also available from Appliance Details.
- Website validation automatically accepts addresses with or without `https://`.
- Unique FloatingActionButton hero tags across the tabbed application.
- Automated tests for support-data persistence, URI generation, website validation, and support-screen display.

## Dependency
Sprint 3 adds the official Flutter `url_launcher` plugin:

```yaml
url_launcher: 6.3.2
```

The working document picker remains pinned:

```yaml
file_picker: 10.3.10
```

## Sprint 3 acceptance test
1. Open an existing appliance and tap **Edit appliance**.
2. In **Customer support**, add a provider, phone number, email, website, and support note.
3. Save the appliance and open the **Support** tab.
4. Search for the appliance or provider.
5. Test the Phone, Email, and Website filters.
6. Tap **Call** and confirm the Android dialer opens.
7. Tap **Email** and confirm the draft contains the appliance details.
8. Tap **Website** and confirm the browser opens the support site.
9. Copy each contact value.
10. Edit the support details from the Support tab.
11. Fully stop and restart the app and confirm the support details remain.
12. Run `flutter analyze` and `flutter test` successfully.

## Emulator note
Some Android emulator images do not include a configured email application or full phone service. In that case, HomeVault shows a clear message instead of crashing. Website launching should work when the emulator has a browser and internet access.

## Current limitation
HomeVault stores support details entered by the user. It does not yet download official manufacturer contacts from the internet or create service tickets. Service history is planned for a later sprint.
